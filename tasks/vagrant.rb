#!/usr/bin/env ruby
require 'json'
require 'net/http'
require 'yaml'
require 'puppet_litmus'
require 'fileutils'

@supported_platforms = {
  'ubuntu14.04' => 'ubuntu/trusty64',
}

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
  image = @supported_platforms[platform]
  raise "Platform '#{platform}' not supported" unless image
  vf = "Vagrant.configure(\"2\") do |config|\n"
  vf << "  config.vm.box = '#{image}'\n"
  vf << "  config.vm.boot_timeout = 600\n"
  # fix username
  vf << "  config.ssh.username = 'vagrant'\n"
  vf << "  config.ssh.password = 'vagrant'\n"
  vf << "  config.ssh.insert_key = false\n"
  vf << "  config.vm.provision \"shell\", inline: <<-SHELL\n"
  vf << "    sed -i 's/ChallengeResponseAuthentication no/ChallengeResponseAuthentication yes/g' /etc/ssh/sshd_config\n"
  vf << "    sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/g' /etc/ssh/sshd_config\n"
  vf << "    service ssh restart\n"
  # set root password
  vf << "    echo 'root:vagrant'|chpasswd\n"
  vf << "  SHELL\n"
  vf << "end\n"
  File.open(file_path, 'w') do |f|
    f.write(vf)
  end
end

def provision(platform, inventory_location)
  include PuppetLitmus
  # TODO: check for ports
  node_name = 'localhost:2222'
  vagrant_location = File.join(inventory_location, '.vagrant', node_name)
  FileUtils.mkdir_p vagrant_location
  generate_vagrantfile(File.join(vagrant_location, 'Vagrantfile'), platform)
  command = 'vagrant up --provider virtualbox'
  run_local_command(command, vagrant_location)
  vm_id = File.read(File.join(vagrant_location, '.vagrant', 'machines', 'default', 'virtualbox', 'index_uuid'))
  if platform_uses_ssh(platform)
    node = { 'name' => node_name,
             'config' => { 'transport' => 'ssh', 'ssh' => { 'user' => 'root', 'host' => 'localhost', 'password' => 'vagrant', 'host-key-check' => false, 'port' => 2222 } },
             'facts' => { 'provisioner' => 'vagrant', 'platform' => platform, 'id' => vm_id } }
    group_name = 'ssh_nodes'
  else
    node = { 'name' => node_name,
             'config' => { 'transport' => 'winrm', 'winrm' => { 'user' => 'Administrator', 'password' => '', 'ssl' => false } },
             'facts' => { 'provisioner' => 'vagrant', 'platform' => platform, 'id' => vm_id } }
    group_name = 'winrm_nodes'
  end
  inventory_full_path = File.join(inventory_location, 'inventory.yaml')
  inventory_hash = if File.file?(inventory_full_path)
                     inventory_hash_from_inventory_file(inventory_full_path)
                   else
                     { 'groups' => [{ 'name' => 'ssh_nodes', 'nodes' => [] }, { 'name' => 'winrm_nodes', 'nodes' => [] }] }
                   end
  add_node_to_group(inventory_hash, node, group_name)
  File.open(inventory_full_path, 'w') { |f| f.write inventory_hash.to_yaml }
  { status: 'ok', node_name: node_name }
end

def tear_down(node_name, inventory_location)
  include PuppetLitmus
  command = 'vagrant destroy -f'
  vagrant_location = File.join(inventory_location, '.vagrant', node_name)
  run_local_command(command, vagrant_location)
  inventory_full_path = File.join(inventory_location, 'inventory.yaml')
  if File.file?(inventory_full_path)
    inventory_hash = inventory_hash_from_inventory_file(inventory_full_path)
    remove_node(inventory_hash, node_name)
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
