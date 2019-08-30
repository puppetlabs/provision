#!/usr/bin/env ruby
require 'json'
require 'net/http'
require 'yaml'
require 'puppet_litmus'
require 'fileutils'
require 'net/ssh'
require_relative '../lib/task_helper'

def generate_vagrantfile(file_path, platform, enable_synced_folder, hyperv_vswitch, hyperv_smb_username, hyperv_smb_password)
  unless enable_synced_folder
    synced_folder = 'config.vm.synced_folder ".", "/vagrant", disabled: true'
  end
  if on_windows?
    # Even though this is the default value in the metadata it isn't sent along if tthe parameter is unspecified for some reason.
    network = "config.vm.network 'public_network', bridge: '#{hyperv_vswitch.nil? ? 'Default Switch' : hyperv_vswitch}'"
    if enable_synced_folder && !hyperv_smb_username.nil? && !hyperv_smb_password.nil?
      synced_folder = "config.vm.synced_folder '.', '/vagrant', type: 'smb', smb_username: '#{hyperv_smb_username}', smb_password: '#{hyperv_smb_password}'"
    end
  end
  vf = <<-VF
Vagrant.configure(\"2\") do |config|
  config.vm.box = '#{platform}'
  config.vm.boot_timeout = 600
  config.ssh.insert_key = false
  #{network}
  #{synced_folder}
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

def configure_remoting(platform, remoting_config_path)
  if platform_uses_ssh(platform)
    command = "vagrant ssh-config > #{remoting_config_path}"
    run_local_command(command, @vagrant_env)
    remoting_config = Net::SSH::Config.load(remoting_config_path, 'default')
    case platform
    when %r{debian.*|ubuntu.*}
      restart_command = 'service ssh restart'
    when %r{centos.*}
      restart_command = 'systemctl restart sshd.service'
    else
      raise ArgumentError, "Unsupported Platform: '#{platform}'"
    end
    # Pre-configure sshd on the platform prior to handing back
    Net::SSH.start(
      remoting_config['hostname'],
      remoting_config['user'],
      port: remoting_config['port'],
      keys: remoting_config['identityfile'],
    ) do |session|
      session.exec!('sudo su -c "cp -r .ssh /root/."')
      session.exec!('sudo su -c "sed -i \"s/.*PermitUserEnvironment\s.*/PermitUserEnvironment yes/g\" /etc/ssh/sshd_config"')
      session.exec!("sudo su -c \"#{restart_command}\"")
    end
  else
    command = "vagrant winrm-config > #{remoting_config_path}"
    run_local_command(command, @vagrant_env)
    remoting_config = Net::SSH::Config.load(remoting_config_path, 'default')
    # TODO: Delete remoting_config_path as it's no longer needed
    # TODO: It's possible we may want to configure WinRM on the target platform beyond the defaults
  end
  remoting_config
end

def provision(platform, inventory_location, enable_synced_folder, hyperv_vswitch, hyperv_smb_username, hyperv_smb_password)
  include PuppetLitmus
  inventory_full_path = File.join(inventory_location, 'inventory.yaml')
  inventory_hash = get_inventory_hash(inventory_full_path)
  vagrant_dirs = Dir.glob("#{File.join(inventory_location, '.vagrant')}/*/").map { |d| File.basename(d) }
  @vagrant_env = File.expand_path(File.join(inventory_location, '.vagrant', get_vagrant_dir(platform, vagrant_dirs)))
  FileUtils.mkdir_p @vagrant_env
  generate_vagrantfile(File.join(@vagrant_env, 'Vagrantfile'), platform, enable_synced_folder, hyperv_vswitch, hyperv_smb_username, hyperv_smb_password)
  provider = on_windows? ? 'hyperv' : 'virtualbox'
  command = "vagrant up --provider #{provider}"
  run_local_command(command, @vagrant_env)
  vm_id = File.read(File.join(@vagrant_env, '.vagrant', 'machines', 'default', provider, 'index_uuid'))

  remote_config_file = platform_uses_ssh(platform) ? File.join(@vagrant_env, 'ssh-config') : File.join(@vagrant_env, 'winrm-config')
  remote_config = configure_remoting(platform, remote_config_file)
  node_name = "#{remote_config['hostname']}:#{remote_config['port']}"

  if platform_uses_ssh(platform)
    node = {
      'name' => node_name,
      'config' => {
        'transport' => 'ssh',
        'ssh' => {
          'user' => 'root',
          'host' => remote_config['hostname'],
          'private-key' => remote_config['identityfile'][0],
          'host-key-check' => remote_config['stricthostkeychecking'],
          'port' => remote_config['port'],
        },
      },
      'facts' => {
        'provisioner' => 'vagrant',
        'platform' => platform,
        'id' => vm_id,
        'vagrant_env' => @vagrant_env,
      },
    }
    group_name = 'ssh_nodes'
  else
    # TODO: Need to figure out where SSL comes from
    remote_config['uses_ssl'] ||= false # TODO: Is the default _actually_ false?
    node = {
      'name' => node_name,
      'config' => {
        'transport'   => 'winrm',
        'winrm'       => {
          'user' => remote_config['user'],
          'password' => remote_config['password'],
          'ssl' => remote_config['uses_ssl'],
        },
      },
      'facts' => {
        'provisioner' => 'vagrant',
        'platform' => platform,
        'id' => vm_id,
        'vagrant_env' => @vagrant_env,
      },
    }
    group_name = 'winrm_nodes'
  end
  add_node_to_group(inventory_hash, node, group_name)
  File.open(inventory_full_path, 'w') { |f| f.write inventory_hash.to_yaml }
  { status: 'ok', node_name: node_name, node: node }
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
puts params
platform = params['platform']
action = params['action']
node_name = params['node_name']
inventory_location = params['inventory']
enable_synced_folder = params['enable_synced_folder'].nil? ? ENV['LITMUS_ENABLE_SYNCED_FOLDER'] : params['enable_synced_folder']
if enable_synced_folder.is_a?(String)
  enable_synced_folder = enable_synced_folder.casecmp('true').zero? ? true : false
end
hyperv_vswitch = params['hyperv_vswitch'].nil? ? ENV['LITMUS_HYPERV_VSWITCH'] : params['hyperv_vswitch']
hyperv_smb_username = params['hyperv_smb_username'].nil? ? ENV['LITMUS_HYPERV_SMB_USERNAME'] : params['hyperv_smb_username']
hyperv_smb_password = params['hyperv_smb_password'].nil? ? ENV['LITMUS_HYPERV_SMB_PASSWORD'] : params['hyperv_smb_password']
raise 'specify a node_name if tearing down' if action == 'tear_down' && node_name.nil?
raise 'specify a platform if provisioning' if action == 'provision' && platform.nil?

begin
  result = provision(platform, inventory_location, enable_synced_folder, hyperv_vswitch, hyperv_smb_username, hyperv_smb_password) if action == 'provision'
  result = tear_down(node_name, inventory_location) if action == 'tear_down'
  puts result.to_json
  exit 0
rescue => e
  puts({ _error: { kind: 'facter_task/failure', msg: e.message } }.to_json)
  exit 1
end
