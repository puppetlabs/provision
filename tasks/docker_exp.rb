#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'yaml'
require 'puppet_litmus'
require_relative '../lib/task_helper'
require_relative '../lib/docker_helper'

# TODO: detect what shell to use
@shell_command = 'bash -lc'

def provision(docker_platform, inventory_location, vars)
  include PuppetLitmus::InventoryManipulation
  inventory_full_path = File.join(inventory_location, '/spec/fixtures/litmus_inventory.yaml')
  inventory_hash = get_inventory_hash(inventory_full_path)
  os_release_facts = docker_image_os_release_facts(docker_platform)

  inventory_node = {
    'config' => {
      'transport' => 'docker',
      'docker' => {
        'shell-command' => @shell_command,
      }
    },
    'facts' => {
      'provisioner' => 'docker_exp',
      'platform' => docker_platform,
      'os-release' => os_release_facts,
    }
  }

  docker_run_opts = ''
  unless vars.nil?
    var_hash = YAML.safe_load(vars)
    inventory_node['vars'] = var_hash
    docker_run_opts = var_hash['docker_run_opts'].flatten.join(' ') unless var_hash['docker_run_opts'].nil?
  end

  if docker_platform.match?(%r{debian|ubuntu})
    docker_run_opts += ' --volume /sys/fs/cgroup:/sys/fs/cgroup:rw' unless docker_run_opts.include?('--volume /sys/fs/cgroup:/sys/fs/cgroup')
    docker_run_opts += ' --cgroupns=host' unless docker_run_opts.include?('--cgroupns')
  end

  creation_command = 'docker run -d -it --privileged '
  creation_command += "#{docker_run_opts} " unless docker_run_opts.nil?
  creation_command += docker_platform

  container_id = run_local_command(creation_command).strip[0..11]

  docker_fix_missing_tty_error_message(container_id) unless platform_is_windows?(docker_platform)

  inventory_node['name'] = container_id
  inventory_node['uri'] = container_id
  inventory_node['facts']['container_id'] = container_id

  add_node_to_group(inventory_hash, inventory_node, 'docker_nodes')
  File.open(inventory_full_path, 'w') { |f| f.write inventory_hash.to_yaml }

  { status: 'ok', node_name: inventory_node['name'], node: inventory_node }
end

params = JSON.parse($stdin.read)
action = params['action']
inventory_location = sanitise_inventory_location(params['inventory'])
node_name = params['node_name']
platform = params['platform']
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
  result = docker_tear_down(node_name, inventory_location) if action == 'tear_down'
  puts result.to_json
  exit 0
rescue StandardError => e
  puts({ _error: { kind: 'provision/docker_exp_failure', msg: e.message } }.to_json)
  exit 1
end
