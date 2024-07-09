#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'net/http'
require 'yaml'
require 'puppet_litmus'
require 'fileutils'
require 'net/ssh'
require_relative '../lib/task_helper'
require_relative '../lib/inventory_helper'

def vagrant_version
  return @vagrant_version if defined?(@vagrant_version)

  @vagrant_version = begin
    command = 'vagrant --version'
    output = run_local_command(command)
    Gem::Version.new(output.strip.split(%r{\s+})[1])
  end
  @vagrant_version
end

def supports_windows_platform?
  # Relies on the winrm-config command added in 2.2.0:
  # https://github.com/hashicorp/vagrant/blob/main/CHANGELOG.md#220-october-16-2018
  vagrant_version >= Gem::Version.new('2.2.0')
end

def generate_vagrantfile(file_path, platform, enable_synced_folder, provider, cpus, memory, hyperv_vswitch, hyperv_smb_username, hyperv_smb_password, box_url)
  synced_folder = 'config.vm.synced_folder ".", "/vagrant", disabled: true' unless enable_synced_folder
  if on_windows?
    # Even though this is the default value in the metadata it isn't sent along if tthe parameter is unspecified for some reason.
    network = "config.vm.network 'public_network', bridge: '#{hyperv_vswitch.nil? ? 'Default Switch' : hyperv_vswitch}'"
    if enable_synced_folder && !hyperv_smb_username.nil? && !hyperv_smb_password.nil?
      synced_folder = "config.vm.synced_folder '.', '/vagrant', type: 'smb', smb_username: '#{hyperv_smb_username}', smb_password: '#{hyperv_smb_password}'"
    end
  end
  if cpus.nil? && memory.nil?
    provider_config_block = ''
  else
    if provider.nil?
      provider = on_windows? ? 'hyperv' : 'virtualbox'
    end
    provider_config_block = <<~PCB
      config.vm.provider "#{provider}" do |v|
          #{"v.cpus = #{cpus}" unless cpus.nil?}
          #{"v.memory = #{memory}" unless memory.nil?}
        end
    PCB
  end
  box_url_config = if box_url
                     "config.vm.box_url = '#{box_url.gsub('%BOX%', platform)}'"
                   else
                     ''
                   end
  vf = <<~VF
    Vagrant.configure("2") do |config|
      config.vm.box = '#{platform}'
      config.vm.boot_timeout = 600
      config.ssh.insert_key = false
      #{box_url_config}
      #{network}
      #{synced_folder}
      #{provider_config_block}
    end
  VF
  File.open(file_path, 'w') do |f|
    f.write(vf)
  end
end

def get_vagrant_dir(platform, vagrant_dirs, int = 0)
  platform_dir = "#{platform}-#{int}".gsub(%r{[/\\]}, '-') # Strip slashes
  platform_dir = get_vagrant_dir(platform, vagrant_dirs, int + 1) if vagrant_dirs.include?(platform_dir)
  platform_dir
end

def configure_remoting(platform, remoting_config_path, password)
  if platform_uses_ssh(platform)
    command = "vagrant ssh-config > \"#{remoting_config_path}\""
    run_local_command(command, @vagrant_env)
    remoting_config = Net::SSH::Config.load(remoting_config_path, 'default')
    # Pre-configure sshd on the platform prior to handing back
    ssh_params = {
      port: remoting_config['port'],
      keys: remoting_config['identityfile'],
      password: password,
      verbose: :debug
    }.compact
    Net::SSH.start(
      remoting_config['hostname'],
      remoting_config['user'],
      **ssh_params,
    ) do |session|
      session.exec!('sudo su -c "cp -r .ssh /root/."')
      session.exec!('sudo su -c "sed -i \"s/.*PermitUserEnvironment\s.*/PermitUserEnvironment yes/g\" /etc/ssh/sshd_config"')
      systemctl = session.exec!('which systemctl 2>/dev/null')
      restart_command = if systemctl.strip.empty?
                          # Debian and Ubuntu use 'ssh' and the EL/Suse family use 'sshd'. This will catch either.
                          'service ssh restart || service sshd restart'
                        else
                          # On Debian/Ubuntu sshd is an alias to the 'ssh' service, and on the EL/Suse families
                          # 'sshd' is the service name, so 'sshd.service' works for all:
                          'systemctl restart sshd.service'
                        end
      session.exec!("sudo su -c \"#{restart_command}\"")
    end
  else
    command = "vagrant winrm-config > \"#{remoting_config_path}\""
    run_local_command(command, @vagrant_env)
    remoting_config = Net::SSH::Config.load(remoting_config_path, 'default')
    # TODO: Delete remoting_config_path as it's no longer needed
    # TODO: It's possible we may want to configure WinRM on the target platform beyond the defaults
  end
  remoting_config
end

def provision(platform, inventory, enable_synced_folder, provider, cpus, memory, hyperv_vswitch, hyperv_smb_username, hyperv_smb_password, box_url, password, vars)
  if platform_is_windows?(platform) && !supports_windows_platform?
    raise "To provision a Windows VM with this task you must have vagrant 2.2.0 or later installed; vagrant seems to be installed at v#{vagrant_version}"
  end

  if provider.nil?
    provider = on_windows? ? 'hyperv' : 'virtualbox'
  end

  vagrant_dirs = Dir.glob("#{File.join(File.dirname(inventory.location), '.vagrant')}/*/").map { |d| File.basename(d) }
  @vagrant_env = File.expand_path(File.join(File.dirname(inventory.location), '.vagrant', get_vagrant_dir(platform, vagrant_dirs)))
  FileUtils.mkdir_p @vagrant_env
  generate_vagrantfile(File.join(@vagrant_env, 'Vagrantfile'), platform, enable_synced_folder, provider, cpus, memory, hyperv_vswitch, hyperv_smb_username, hyperv_smb_password, box_url)
  command = "vagrant up --provider #{provider}"
  run_local_command(command, @vagrant_env)
  vm_id = File.read(File.join(@vagrant_env, '.vagrant', 'machines', 'default', provider, 'index_uuid'))

  remote_config_file = platform_uses_ssh(platform) ? File.join(@vagrant_env, 'ssh-config') : File.join(@vagrant_env, 'winrm-config')
  remote_config = configure_remoting(platform, remote_config_file, password)
  node_name = "#{remote_config['hostname']}:#{remote_config['port']}"

  if platform_uses_ssh(platform)
    node = {
      'name' => node_name,
      'uri' => node_name,
      'config' => {
        'transport' => 'ssh',
        'ssh' => {
          'user' => remote_config['user'],
          'host' => remote_config['hostname'],
          'host-key-check' => remote_config['stricthostkeychecking'],
          'port' => remote_config['port'],
          'run-as' => 'root',
          'connect-timeout' => 120
        }
      },
      'facts' => {
        'provisioner' => 'vagrant',
        'platform' => platform,
        'id' => vm_id,
        'vagrant_env' => @vagrant_env
      }
    }
    node['config']['ssh']['private-key'] = remote_config['identityfile'][0] if remote_config['identityfile']
    node['config']['ssh']['password'] = password if password
    group_name = 'ssh_nodes'
  else
    # TODO: Need to figure out where SSL comes from
    remote_config['uses_ssl'] ||= false # TODO: Is the default _actually_ false?
    node = {
      'name' => node_name,
      'uri' => node_name,
      'config' => {
        'transport' => 'winrm',
        'winrm' => {
          'user' => remote_config['user'],
          'password' => remote_config['password'],
          'ssl' => remote_config['uses_ssl'],
          'connect-timeout' => 120
        }
      },
      'facts' => {
        'provisioner' => 'vagrant',
        'platform' => platform,
        'id' => vm_id,
        'vagrant_env' => @vagrant_env
      }
    }
    group_name = 'winrm_nodes'
  end
  # Add the vars hash to the node if they are passed exists
  unless vars.nil?
    var_hash = YAML.safe_load(vars)
    node['vars'] = var_hash
  end
  inventory.add(node, group_name).save
  { status: 'ok', node_name: node_name, node: node }
end

def tear_down(node_name, inventory)
  command = 'vagrant destroy -f'
  node = inventory.lookup(node_name, group: 'ssh_nodes')
  vagrant_env = node['facts']['vagrant_env']
  run_local_command(command, vagrant_env)
  FileUtils.rm_r(vagrant_env)
  inventory.remote(node).save
  { status: 'ok' }
end

def vagrant
  params = JSON.parse($stdin.read)
  warn params
  platform = params['platform']
  action = params['action']
  node_name = params['node_name']
  vars = params['vars']
  inventory = InventoryHelper.open(params['inventory'])
  enable_synced_folder = params['enable_synced_folder'].nil? ? ENV.fetch('VAGRANT_ENABLE_SYNCED_FOLDER', nil) : params['enable_synced_folder']
  enable_synced_folder = enable_synced_folder.casecmp('true').zero? if enable_synced_folder.is_a?(String)
  provider            = params['provider'].nil? ? ENV.fetch('VAGRANT_PROVIDER', nil) : params['provider']
  cpus                = params['cpus'].nil? ? ENV.fetch('VAGRANT_CPUS', nil) : params['cpus']
  memory              = params['memory'].nil? ? ENV.fetch('VAGRANT_MEMORY', nil) : params['memory']
  hyperv_vswitch      = params['hyperv_vswitch'].nil? ? ENV.fetch('VAGRANT_HYPERV_VSWITCH', nil) : params['hyperv_vswitch']
  hyperv_smb_username = params['hyperv_smb_username'].nil? ? ENV.fetch('VAGRANT_HYPERV_SMB_USERNAME', nil) : params['hyperv_smb_username']
  hyperv_smb_password = params['hyperv_smb_password'].nil? ? ENV.fetch('VAGRANT_HYPERV_SMB_PASSWORD', nil) : params['hyperv_smb_password']
  box_url             = params['box_url'].nil? ? ENV.fetch('VAGRANT_BOX_URL', nil) : params['box_url']
  password            = params['password'].nil? ? ENV.fetch('VAGRANT_PASSWORD', nil) : params['password']
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
    result = provision(platform, inventory, enable_synced_folder, provider, cpus, memory, hyperv_vswitch, hyperv_smb_username, hyperv_smb_password, box_url, password, vars) if action == 'provision'
    result = tear_down(node_name, inventory) if action == 'tear_down'
    puts result.to_json
    exit 0
  rescue StandardError => e
    puts({ _error: { kind: 'provision/vagrant_failure', msg: e.message } }.to_json)
    exit 1
  end
end

vagrant if __FILE__ == $PROGRAM_NAME
