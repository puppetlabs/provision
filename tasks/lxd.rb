#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'yaml'
require_relative '../lib/task_helper'
require_relative '../lib/inventory_helper'

# Provision and teardown instances on LXD
class LXDProvision
  attr_reader :node_name, :retries
  attr_reader :platform, :inventory, :vars, :action, :options

  def provision
    lxd_remote = options[:remote] || lxd_default_remote

    lxd_flags = []
    options[:profiles]&.each { |p| lxd_flags << "--profile #{p}" }
    lxd_flags << "--type #{options[:instance_type]}" if options[:instance_type]
    lxd_flags << "--storage #{options[:storage]}" if options[:storage]
    lxd_flags << '--vm' if options[:vm]

    creation_command = "lxc -q create #{platform} #{lxd_remote}: #{lxd_flags.join(' ')}"
    container_id = run_local_command(creation_command).chomp.split[-1]

    # add agent cdrom device if required
    container_properties = YAML.safe_load(run_local_command("lxc -q config show #{lxd_remote}:#{container_id} -e"))
    if container_properties['config']&.fetch('image.requirements.cdrom_agent', nil).to_s == 'true'
      run_local_command("lxc -q config device add #{lxd_remote}:#{container_id} agent disk source=agent:config")
    end

    begin
      start_command = "lxc -q start #{lxd_remote}:#{container_id}"
      run_local_command(start_command)

      # wait here for a bit until instance can accept commands
      state_command = "lxc -q exec #{lxd_remote}:#{container_id} uptime"
      attempt = 0
      begin
        run_local_command(state_command)
      rescue StandardError => e
        raise "Giving up waiting for #{lxd_remote}:#{container_id} to enter running state. Got error: #{e.message}" if retries > 0 && attempt > retries

        attempt += 1
        sleep 2**attempt
        retry if retries > 0
      end
    rescue StandardError
      run_local_command("lxc -q delete #{lxd_remote}:#{container_id} -f")
      raise
    end

    facts = {
      provisioner: 'lxd',
      container_id: container_id,
      platform: platform
    }

    options.each do |option|
      facts[:"lxd_#{option[0]}"] = option[1] unless option[1].to_s.empty?
    end

    node = {
      uri: container_id,
      config: {
        transport: 'lxd',
        lxd: {
          remote: lxd_remote,
          'shell-command': 'sh -lc'
        }
      },
      facts: facts
    }

    node[:vars] = vars unless vars.nil?

    inventory.add(node, 'lxd_nodes').save

    { status: 'ok', node_name: container_id, node: node }
  end

  def tear_down
    node = inventory.lookup(node_name, group: 'lxd_nodes')

    raise "node_name #{node_name} not found in inventory" unless node

    run_local_command("lxc -q delete #{node['config']['lxd']['remote']}:#{node['facts']['container_id']} -f")

    inventory.remove(node).save

    { status: 'ok' }
  end

  def task(**params)
    finalize_params!(params)

    @action = params.delete(:action)
    @retries = params.delete(:retries)&.to_i || 1
    @platform = params.delete(:platform)
    @node_name = params.delete(:node_name)
    @vars = YAML.safe_load(params.delete(:vars) || '~')

    @inventory = InventoryHelper.open(params.delete(:inventory))

    @options = params.reject { |k, _v| k.start_with? '_' }
    method(action).call
  end

  def lxd_default_remote
    @lxd_default_remote ||= run_local_command('lxc -q remote get-default').chomp
    @lxd_default_remote
  end

  # add environment provided parameters (puppet litmus)
  def finalize_params!(params)
    ['remote', 'profiles', 'storage', 'instance_type', 'vm'].each do |p|
      params[p] = YAML.safe_load(ENV.fetch("LXD_#{p.upcase}", '~')) if params[p].to_s.empty?
    end
    params.compact!
  end

  class << self
    def run
      params = JSON.parse($stdin.read, symbolize_names: true)

      case params[:action]
      when 'tear_down'
        raise 'do not specify platform when tearing down' if params[:platform]
        raise 'node_name required when tearing down' unless params[:node_name]
      when 'provision'
        raise 'do not specify node_name when provisioning' if params[:node_name]
        raise 'platform required, when provisioning' unless params[:platform]
      else
        raise "invalid action: #{params[:action]}" if params[:action]

        raise 'must specify a valid action'
      end

      result = new.task(**params)
      puts result.to_json
    rescue StandardError => e
      puts({ _error: { kind: 'provision/lxd_failure', msg: e.message, details: { backtraces: e.backtrace } } }.to_json)
      exit 1
    end
  end
end

LXDProvision.run if __FILE__ == $PROGRAM_NAME
