#!/usr/bin/env ruby
require 'json'
require 'net/http'
require 'yaml'
require 'puppet_litmus'
require 'fileutils'
require 'net/ssh'
require_relative '../lib/task_helper'

def generate_vagrantfile(file_path, platform, hyperv_vswitch, hyperv_smb_username, hyperv_smb_password)
  if on_windows?
    # Even though this is the default value in the metadata it isn't sent along if tthe parameter is unspecified for some reason.
    network = "config.vm.network 'public_network', bridge: '#{hyperv_vswitch.nil? ? 'Default Switch' : hyperv_vswitch}'"
    unless hyperv_smb_username.nil? || hyperv_smb_password.nil?
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

def on_windows?
  # Stolen directly from Puppet::Util::Platform.windows?
  # Ruby only sets File::ALT_SEPARATOR on Windows and the Ruby standard
  # library uses that to test what platform it's on. In some places we
  # would use Puppet.features.microsoft_windows?, but this method can be
  # used to determine the behavior of the underlying system without
  # requiring features to be initialized and without side effect.
  !!File::ALT_SEPARATOR # rubocop:disable Style/DoubleNegation
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
  when %r{debian.*|ubuntu.*}
    restart_command = 'service ssh restart'
  when %r{centos.*}
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

def provision(platform, inventory_location, hyperv_vswitch, hyperv_smb_username, hyperv_smb_password)
  include PuppetLitmus
  inventory_full_path = File.join(inventory_location, 'inventory.yaml')
  inventory_hash = get_inventory_hash(inventory_full_path)
  vagrant_dirs = Dir.glob("#{File.join(inventory_location, '.vagrant')}/*/").map { |d| File.basename(d) }
  @vagrant_env = File.join(inventory_location, '.vagrant', get_vagrant_dir(platform, vagrant_dirs))
  FileUtils.mkdir_p @vagrant_env
  generate_vagrantfile(File.join(@vagrant_env, 'Vagrantfile'), platform, hyperv_vswitch, hyperv_smb_username, hyperv_smb_password)
  provider = on_windows? ? 'hyperv' : 'virtualbox'
  command = "vagrant up --provider #{provider}"
  run_local_command(command, @vagrant_env)
  ssh_config = configure_ssh(platform, File.join(@vagrant_env, 'ssh-config'))
  node_name = "#{ssh_config['hostname']}:#{ssh_config['port']}"
  vm_id = File.read(File.join(@vagrant_env, '.vagrant', 'machines', 'default', provider, 'index_uuid'))
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
puts params
platform = params['platform']
action = params['action']
node_name = params['node_name']
inventory_location = params['inventory']
hyperv_vswitch = params['hyperv_vswitch'].nil? ? ENV['LITMUS_HYPERV_VSWITCH'] : params['hyperv_vswitch']
hyperv_smb_username = params['hyperv_smb_username'].nil? ? ENV['LITMUS_HYPERV_SMB_USERNAME'] : params['hyperv_smb_username']
hyperv_smb_password = params['hyperv_smb_password'].nil? ? ENV['LITMUS_HYPERV_SMB_PASSWORD'] : params['hyperv_smb_password']
raise 'specify a node_name if tearing down' if action == 'tear_down' && node_name.nil?
raise 'specify a platform if provisioning' if action == 'provision' && platform.nil?

begin
  result = provision(platform, inventory_location, hyperv_vswitch, hyperv_smb_username, hyperv_smb_password) if action == 'provision'
  result = tear_down(node_name, inventory_location) if action == 'tear_down'
  puts result.to_json
  exit 0
rescue => e
  puts({ _error: { kind: 'facter_task/failure', msg: e.message } }.to_json)
  exit 1
end
