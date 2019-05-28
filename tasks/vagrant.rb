#!/usr/bin/env ruby
require 'json'
require 'net/http'
require 'yaml'
require 'puppet_litmus'
require 'fileutils'
require 'net/ssh'

def run_local_command(command, wd = Dir.pwd)
  stdout, stderr, status = Open3.capture3(command, chdir: wd)
  error_message = "Attempted to run\ncommand:'#{command}'\nstdout:#{stdout}\nstderr:#{stderr}"
  raise error_message unless status.to_i.zero?
  stdout
end

def platform_uses_ssh(platform)
  uses_ssh = if platform !~ %r{win-}
               true
             else
               false
             end
  uses_ssh
end

def generate_vagrantfile(file_path, platform)
  vf = <<-VF
Vagrant.configure(\"2\") do |config|
  config.vm.box = '#{platform}'
  config.vm.boot_timeout = 600
  config.ssh.insert_key = false
end
VF
  File.open(file_path, 'w') do |f|
    f.write(vf)
  end
end

def get_vagrant_dir(platform, vagrant_dirs, i = 0)
  platform_dir = "#{platform}-#{i}"
  if vagrant_dirs.include?(platform_dir)
    platform_dir = get_vagrant_dir(platform, vagrant_dirs, i + 1)
  end
  platform_dir
end

def configure_ssh(platform, ssh_config_path)
  command = "vagrant ssh-config > #{ssh_config_path}"
  run_local_command(command, @vagrant_env)
  ssh_config = Net::SSH::Config.load(ssh_config_path, 'default')
  case platform
  when %r{/debian.*|ubuntu.*/}
    restart_command = 'service ssh restart'
  when %r{/centos.*/}
    restart_command = 'systemctl restart sshd.service'
  else
    raise ArgumentError, "Unsupported Platform: '#{platform}'"
  end
  Net::SSH.start(
    ssh_config['hostname'],
    ssh_config['user'],
    port: ssh_config['port'],
    keys: ssh_config['identityfile'],
  ) do |session|
    session.exec!('sudo su -c "cp -r .ssh /root/."')
    session.exec!('sudo su -c "sed -i \"s/.*PermitUserEnvironment\s.*/PermitUserEnvironment yes/g\" /etc/ssh/sshd_config"')
    session.exec!("sudo su -c \"#{restart_command}\"")
  end
  ssh_config
end

def provision(platform, inventory_location)
  include PuppetLitmus
  inventory_full_path = File.join(inventory_location, 'inventory.yaml')
  inventory_hash = if File.file?(inventory_full_path)
                     inventory_hash_from_inventory_file(inventory_full_path)
                   else
                     { 'groups' => [{ 'name' => 'ssh_nodes', 'nodes' => [] }, { 'name' => 'winrm_nodes', 'nodes' => [] }] }
                   end
  vagrant_dirs = Dir.glob("#{File.join(inventory_location, '.vagrant')}/*/").map { |d| File.basename(d) }
  @vagrant_env = File.join(inventory_location, '.vagrant', get_vagrant_dir(platform, vagrant_dirs))
  FileUtils.mkdir_p @vagrant_env
  generate_vagrantfile(File.join(@vagrant_env, 'Vagrantfile'), platform)
  command = 'vagrant up --provider virtualbox'
  run_local_command(command, @vagrant_env)
  ssh_config = configure_ssh(platform, File.join(@vagrant_env, 'ssh-config'))
  node_name = "#{ssh_config['hostname']}:#{ssh_config['port']}"
  vm_id = File.read(File.join(@vagrant_env, '.vagrant', 'machines', 'default', 'virtualbox', 'index_uuid'))
  if platform_uses_ssh(platform)
    node = { 'name' => node_name,
             'config' => { 'transport' => 'ssh', 'ssh' => { 'user' => 'root', 'host' => ssh_config['hostname'], 'private-key' => ssh_config['identityfile'][0],
                                                            'host-key-check' => ssh_config['stricthostkeychecking'], 'port' => ssh_config['port'] } },
             'facts' => { 'provisioner' => 'vagrant', 'platform' => platform, 'id' => vm_id, 'vagrant_env' => @vagrant_env } }
    group_name = 'ssh_nodes'
  else
    node = { 'name' => node_name,
             'config' => { 'transport' => 'winrm', 'winrm' => { 'user' => 'Administrator', 'password' => '', 'ssl' => false } },
             'facts' => { 'provisioner' => 'vagrant', 'platform' => platform, 'id' => vm_id, 'vagrant_env' => @vagrant_env } }
    group_name = 'winrm_nodes'
  end
  add_node_to_group(inventory_hash, node, group_name)
  File.open(inventory_full_path, 'w') { |f| f.write inventory_hash.to_yaml }
  { status: 'ok', node_name: node_name }
end

def tear_down(node_name, inventory_location)
  include PuppetLitmus
  command = 'vagrant destroy -f'
  inventory_full_path = File.join(inventory_location, 'inventory.yaml')
  if File.file?(inventory_full_path)
    inventory_hash = inventory_hash_from_inventory_file(inventory_full_path)
    vagrant_env = facts_from_node(inventory_hash, node_name)['vagrant_env']
    run_local_command(command, vagrant_env)
    remove_node(inventory_hash, node_name)
    FileUtils.rm_r(vagrant_env)
  end
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
