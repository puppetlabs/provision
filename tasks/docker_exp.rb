#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'yaml'
require_relative '../lib/task_helper'
require_relative '../lib/docker_helper'
require_relative '../lib/inventory_helper'

# TODO: detect what shell to use
@shell_command = 'bash -lc'

def provision(docker_platform, inventory, vars)
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

  inventory.add(inventory_node, 'docker_nodes').save

  { status: 'ok', node_name: inventory_node['name'], node: inventory_node }
end

params = JSON.parse($stdin.read)
action = params['action']
inventory = InventoryHelper.open(params['inventory'])
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
  result = provision(platform, inventory, vars) if action == 'provision'
  if action == 'tear_down'
    node = inventory.lookup(node_name, group: 'docker_nodes')
    result = docker_tear_down(node['facts']['container_id'])
    inventory.remove(node).save
  end
  puts result.to_json
  exit 0
rescue StandardError => e
  puts({ _error: { kind: 'provision/docker_exp_failure', msg: e.message, backtrace: e.backtrace } }.to_json)
  exit 1
end
