#!/usr/bin/env ruby
require 'json'
require 'yaml'
require 'solid_waffle'

def run_local_command(command)
  stdout, stderr, status = Open3.capture3(command)
  error_message = "Attempted to run\ncommand:'#{command}'\nstdout:#{stdout}\nstderr:#{stderr}"
  raise error_message unless status.to_i.zero?
  stdout
end

def install_ssh_components(platform, container)
  case platform
  when %r{debian}, %r{ubuntu}
    run_local_command("docker exec #{container} apt-get update")
    run_local_command("docker exec #{container} apt-get install -y openssh-server openssh-client")
  when %r{cumulus}
    run_local_command("docker exec #{container} apt-get update")
    run_local_command("docker exec #{container} apt-get install -y openssh-server openssh-client")
  when %r{fedora-(2[2-9])}
    run_local_command("docker exec #{container} dnf clean all")
    run_local_command("docker exec #{container} dnf install -y sudo openssh-server openssh-clients")
    run_local_command("docker exec #{container} ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key")
    run_local_command("docker exec #{container} ssh-keygen -t dsa -f /etc/ssh/ssh_host_dsa_key")
  when %r{centos}, %r{^el-}, %r{eos}, %r{fedora}, %r{oracle}, %r{redhat}, %r{scientific}
    run_local_command("docker exec #{container} yum clean all")
    run_local_command("docker exec #{container} yum install -y sudo openssh-server openssh-clients")
    run_local_command("docker exec #{container} ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key -N ''")
    run_local_command("docker exec #{container} ssh-keygen -t dsa -f /etc/ssh/ssh_host_dsa_key -N ''")
  when %r{opensuse}, %r{sles}
    run_local_command("docker exec #{container} zypper -n in openssh")
    run_local_command("docker exec #{container} ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key")
    run_local_command("docker exec #{container} ssh-keygen -t dsa -f /etc/ssh/ssh_host_dsa_key")
    run_local_command("docker exec #{container} sed -ri 's/^#?UsePAM .*/UsePAM no/' /etc/ssh/sshd_config")
  when %r{archlinux}
    run_local_command("docker exec #{container} pacman --noconfirm -Sy archlinux-keyring")
    run_local_command("docker exec #{container} pacman --noconfirm -Syu")
    run_local_command("docker exec #{container} pacman -S --noconfirm openssh")
    run_local_command("docker exec #{container} ssh-keygen -A")
    run_local_command("docker exec #{container} sed -ri 's/^#?UsePAM .*/UsePAM no/' /etc/ssh/sshd_config")
    run_local_command("docker exec #{container} systemctl enable sshd")
  else
    raise "platform #{platform} not yet supported on docker"
  end

  # Make sshd directory, set root password
  run_local_command("docker exec #{container} mkdir -p /var/run/sshd")
  run_local_command("docker exec #{container} bash -c 'echo root:root | /usr/sbin/chpasswd'")
end

def fix_ssh(platform, container)
  run_local_command("docker exec #{container} sed -ri 's/^#?PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config")
  run_local_command("docker exec #{container} sed -ri 's/^#?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config")
  run_local_command("docker exec #{container} sed -ri 's/^#?UseDNS .*/UseDNS no/' /etc/ssh/sshd_config")
  run_local_command("docker exec #{container} sed -e '/HostKey.*ssh_host_e.*_key/ s/^#*/#/' -ri /etc/ssh/sshd_config")
  case platform
  when %r{debian}, %r{ubuntu}
    run_local_command("docker exec #{container} service ssh restart")
  when %r{centos}, %r{^el-}, %r{eos}, %r{fedora}, %r{oracle}, %r{redhat}, %r{scientific}
    if container !~ %r{7}
      run_local_command("docker exec #{container} service sshd restart")
    else
      run_local_command("docker exec -d #{container} /usr/sbin/sshd -D")
    end
  else
    raise "platform #{platform} not yet supported on docker"
  end
end

def provision(platform, inventory_location)
  include SolidWaffle
  inventory_full_path = File.join(inventory_location, 'inventory.yaml')
  inventory_hash = if File.file?(inventory_full_path)
                     inventory_hash_from_inventory_file(inventory_full_path)
                   else
                     { 'groups' => [{ 'name' => 'ssh_nodes', 'nodes' => [] }, { 'name' => 'winrm_nodes', 'nodes' => [] }] }
                   end
  warn '!!! Using private port forwarding!!!'
  platform, version = platform.split(':')
  front_facing_port = 2222
  platform = platform.sub(%r{/}, '_')
  full_container_name = "#{platform}_#{version}-#{front_facing_port}"
  (front_facing_port..2230).each do |i|
    front_facing_port = i
    full_container_name = "#{platform}_#{version}-#{front_facing_port}"
    _stdout, stderr, _status = Open3.capture3("docker port #{full_container_name}")
    break unless (stderr =~ %r{No such container}i).nil?
    raise 'All front facing ports are in use.' if front_facing_port == 2230
  end
  puts "Provisioning #{full_container_name}"
  creation_command = "docker run -d -it -p #{front_facing_port}:22 --name #{full_container_name} #{platform}"
  run_local_command(creation_command)
  install_ssh_components(platform, full_container_name)
  fix_ssh(platform, full_container_name)
  hostname = 'localhost'
  node = { 'name' => "#{hostname}:#{front_facing_port}",
           'config' => { 'transport' => 'ssh',
                         'ssh' => { 'user' => 'root', 'password' => 'root', 'port' => front_facing_port, 'host-key-check' => false } },
           'facts' => { 'provisioner' => 'docker', 'container_name' => full_container_name } }
  group_name = 'ssh_nodes'
  add_node_to_group(inventory_hash, node, group_name)
  File.open(inventory_full_path, 'w') { |f| f.write inventory_hash.to_yaml }
  { status: 'ok', node_name: hostname }
end

def tear_down(node_name, inventory_location)
  include SolidWaffle
  inventory_full_path = File.join(inventory_location, 'inventory.yaml')
  raise "Unable to find '#{inventory_full_path}'" unless File.file?(inventory_full_path)
  inventory_hash = inventory_hash_from_inventory_file(inventory_full_path)
  node_facts = facts_from_node(inventory_hash, node_name)
  remove_docker = "docker rm -f #{node_facts['container_name']}"
  run_local_command(remove_docker)
  remove_node(inventory_hash, node_name)
  puts "Removed #{node_name}"
  File.open(inventory_full_path, 'w') { |f| f.write inventory_hash.to_yaml }
  { status: 'ok' }
end

params = JSON.parse(STDIN.read)
platform = params['platform']
action = params['action']
node_name = params['node_name']
inventory_location = params['inventory']
raise 'specify a node_name if tearing down' if action == 'tear_down' && node_name.nil?
raise 'specify a platform if provisioning' if action == 'provision' && platform.nil?

begin
  result = provision(platform, inventory_location) if action == 'provision'
  result = tear_down(node_name, inventory_location) if action == 'tear_down'
  puts result.to_json
  exit 0
rescue => e
  puts({ _error: { kind: 'facter_task/failure', msg: e.message } }.to_json)
  exit 1
end
