#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'yaml'
require 'puppet_litmus'
require_relative '../lib/task_helper'

def install_ssh_components(distro, version, container)
  case distro
  when %r{debian}, %r{ubuntu}, %r{cumulus}
    warn '!!! Disabling ESM security updates for ubuntu - no access without privilege !!!'
    run_local_command("docker exec #{container} rm -f /etc/apt/sources.list.d/ubuntu-esm-infra-trusty.list")
    run_local_command("docker exec #{container} apt-get update")
    run_local_command("docker exec #{container} apt-get install -y openssh-server openssh-client")
  when %r{fedora}
    run_local_command("docker exec #{container} dnf clean all")
    run_local_command("docker exec #{container} dnf install -y sudo openssh-server openssh-clients")
    run_local_command("docker exec #{container} ssh-keygen -A")
  when %r{centos}, %r{^el-}, %r{eos}, %r{oracle}, %r{ol}, %r{redhat}, %r{scientific}, %r{amzn}
    if version == '6'
      # sometimes the redhat 6 variant containers like to eat their rpmdb, leading to
      # issues with "rpmdb: unable to join the environment" errors
      # This "fix" is from https://www.srv24x7.com/criticalyum-main-error-rpmdb-open-failed/
      run_local_command("docker exec #{container} bash -exc \"rm -f /var/lib/rpm/__db*; "\
        'db_verify /var/lib/rpm/Packages; '\
        'rpm --rebuilddb; '\
        'yum clean all; '\
        'yum install -y sudo openssh-server openssh-clients"')
    else
      run_local_command("docker exec #{container} yum install -y sudo openssh-server openssh-clients")
    end
    ssh_folder = run_local_command("docker exec #{container} ls /etc/ssh/")
    run_local_command("docker exec #{container} ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key -N \"\"") unless ssh_folder.include?('ssh_host_rsa_key')
    run_local_command("docker exec #{container} ssh-keygen -t dsa -f /etc/ssh/ssh_host_dsa_key -N \"\"") unless ssh_folder.include?('ssh_host_dsa_key')
  when %r{opensuse}, %r{sles}
    run_local_command("docker exec #{container} zypper -n in openssh")
    run_local_command("docker exec #{container} ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key")
    run_local_command("docker exec #{container} ssh-keygen -t dsa -f /etc/ssh/ssh_host_dsa_key")
    run_local_command("docker exec #{container} sed -ri \"s/^#?UsePAM .*/UsePAM no/\" /etc/ssh/sshd_config")
  when %r{archlinux}
    run_local_command("docker exec #{container} pacman --noconfirm -Sy archlinux-keyring")
    run_local_command("docker exec #{container} pacman --noconfirm -Syu")
    run_local_command("docker exec #{container} pacman -S --noconfirm openssh")
    run_local_command("docker exec #{container} ssh-keygen -A")
    run_local_command("docker exec #{container} sed -ri \"s/^#?UsePAM .*/UsePAM no/\" /etc/ssh/sshd_config")
    run_local_command("docker exec #{container} systemctl enable sshd")
  else
    raise "distribution #{distro} not yet supported on docker"
  end

  # Make sshd directory, set root password
  run_local_command("docker exec #{container} mkdir -p /var/run/sshd")
  run_local_command("docker exec #{container} bash -c \"echo root:root | /usr/sbin/chpasswd\"")
end

def fix_ssh(distro, version, container)
  run_local_command("docker exec #{container} sed -ri \"s/^#?PermitRootLogin .*/PermitRootLogin yes/\" /etc/ssh/sshd_config")
  run_local_command("docker exec #{container} sed -ri \"s/^#?PasswordAuthentication .*/PasswordAuthentication yes/\" /etc/ssh/sshd_config")
  run_local_command("docker exec #{container} sed -ri \"s/^#?UseDNS .*/UseDNS no/\" /etc/ssh/sshd_config")
  run_local_command("docker exec #{container} sed -e \"/HostKey.*ssh_host_e.*_key/ s/^#*/#/\" -ri /etc/ssh/sshd_config")
  case distro
  when %r{debian}, %r{ubuntu}
    run_local_command("docker exec #{container} service ssh restart")
  when %r{centos}, %r{^el-}, %r{eos}, %r{fedora}, %r{ol}, %r{redhat}, %r{scientific}, %r{amzn}
    # Current RedHat/CentOs 7 packs an old version of pam, which are missing a
    # crucial patch when running unprivileged containers.  See:
    # https://bugzilla.redhat.com/show_bug.cgi?id=1728777
    if distro =~ %r{redhat|centos} && version =~ %r{^7}
      run_local_command("docker exec #{container} sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd")
    end

    if !%r{^(7|8|2)}.match?(version)
      run_local_command("docker exec #{container} service sshd restart")
    else
      run_local_command("docker exec #{container} /usr/sbin/sshd")
    end
  else
    raise "distribution #{distro} not yet supported on docker"
  end
end

def get_image_os_release_facts(image)
  os_release_facts = {}
  begin
    os_release = run_local_command("docker run --rm #{image} cat /etc/os-release")
    # The or-release file is a newline-separated list of environment-like
    # shell-compatible variable assignments.
    re = '^(.+)=(.+)'
    os_release.each_line do |line|
      line = line.strip || line
      next unless !line.nil? && !line.empty?

      _, key, value = line.match(re).to_a
      # The values seems to be quoted most of the time, however debian only quotes
      # some of the values :/.  Parse it, as if it was a JSON string.
      value = JSON.parse(value) unless value[0] != '"'
      os_release_facts[key] = value
    end
  rescue
    # fall through to parsing the id and version from the image if it doesn't have `/etc/os-release`
    id, version_id = image.split(':')
    id = id.sub(%r{/}, '_')
    os_release_facts['ID'] = id
    os_release_facts['VERSION_ID'] = version_id
  end
  os_release_facts
end

def provision(image, inventory_location, vars)
  include PuppetLitmus::InventoryManipulation
  inventory_full_path = File.join(inventory_location, '/spec/fixtures/litmus_inventory.yaml')
  inventory_hash = get_inventory_hash(inventory_full_path)
  os_release_facts = get_image_os_release_facts(image)
  distro = os_release_facts['ID']
  version = os_release_facts['VERSION_ID']
  hostname = 'localhost'
  group_name = 'ssh_nodes'
  warn '!!! Using private port forwarding!!!'
  front_facing_port = 2222
  (front_facing_port..2230).each do |i|
    front_facing_port = i
    ports = "#{front_facing_port}->22"
    list_command = 'docker container ls -a'
    stdout = run_local_command(list_command)
    break unless stdout.include?(ports)
    raise 'All front facing ports are in use.' if front_facing_port == 2230
  end
  full_container_name = "#{image.gsub(%r{[\/:\.]}, '_')}-#{front_facing_port}"
  deb_family_systemd_volume = if (image =~ %r{debian|ubuntu}) && (image !~ %r{debian8|ubuntu14})
                                '--volume /sys/fs/cgroup:/sys/fs/cgroup:ro'
                              else
                                ''
                              end
  node = {
    'uri' => "#{hostname}:#{front_facing_port}",
    'config' => {
      'transport' => 'ssh',
      'ssh' => { 'user' => 'root', 'password' => 'root', 'port' => front_facing_port, 'host-key-check' => false },
    },
    'facts' => {
      'provisioner' => 'docker',
      'container_name' => full_container_name,
      'platform' => image,
      'os-release' => os_release_facts,
    },
  }
  unless vars.nil?
    var_hash = YAML.safe_load(vars)
    node['vars'] = var_hash
    docker_run_opts = var_hash['docker_run_opts'].flatten.join(' ') unless var_hash['docker_run_opts'].nil?
  end
  creation_command = "docker run -d -it --privileged #{deb_family_systemd_volume} --tmpfs /tmp:exec -p #{front_facing_port}:22 --name #{full_container_name} "
  creation_command += "#{docker_run_opts} " unless docker_run_opts.nil?
  creation_command += image
  run_local_command(creation_command).strip
  install_ssh_components(distro, version, full_container_name)
  fix_ssh(distro, version, full_container_name)
  add_node_to_group(inventory_hash, node, group_name)
  File.open(inventory_full_path, 'w') { |f| f.write inventory_hash.to_yaml }
  { status: 'ok', node_name: "#{hostname}:#{front_facing_port}", node: node }
end

def tear_down(node_name, inventory_location)
  include PuppetLitmus::InventoryManipulation
  inventory_full_path = File.join(inventory_location, '/spec/fixtures/litmus_inventory.yaml')
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
inventory_location = sanitise_inventory_location(params['inventory'])
vars = params['vars']
raise 'specify a node_name when tearing down' if action == 'tear_down' && node_name.nil?
raise 'specify a platform when provisioning' if action == 'provision' && platform.nil?
unless node_name.nil? ^ platform.nil?
  case action
  when 'tear_down'
    raise 'specify only a node_name, not platform, when tearing down'
  when 'provision'
    raise 'specify only a platform, not node_name, when provisioning'
  else
    raise 'specify only one of: node_name, platform'
  end
end

begin
  result = provision(platform, inventory_location, vars) if action == 'provision'
  result = tear_down(node_name, inventory_location) if action == 'tear_down'
  puts result.to_json
  exit 0
rescue => e
  puts({ _error: { kind: 'provision/docker_failure', msg: e.message, backtrace: e.backtrace } }.to_json)
  exit 1
end
