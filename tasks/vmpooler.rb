#!/usr/bin/env ruby
require 'json'
require 'net/http'
require 'yaml'
require 'puppet_litmus'
require_relative '../lib/task_helper'

def provision(platform, inventory_location, vars)
  include PuppetLitmus::InventoryManipulation
  unless vars.nil?
    vars_hash = YAML.safe_load(vars)
  end
  vmpooler_hostname = if ENV['VMPOOLER_HOSTNAME'].nil?
                        'vcloud.delivery.puppetlabs.net'
                      else
                        ENV['VMPOOLER_HOSTNAME']
                      end
  uri = URI.parse("http://#{vmpooler_hostname}/vm/#{platform}")

  token = token_from_fogfile
  headers = { 'X-AUTH-TOKEN' => token } unless token.nil?

  http = Net::HTTP.new(uri.host, uri.port)
  request = if token.nil?
              Net::HTTP::Post.new(uri.request_uri)
            else
              Net::HTTP::Post.new(uri.request_uri, headers)
            end
  reply = http.request(request)
  raise "Error: #{reply}: #{reply.message}" unless reply.is_a?(Net::HTTPSuccess)

  data = JSON.parse(reply.body)
  raise "VMPooler is not ok: #{data.inspect}" unless data['ok'] == true

  hostname = "#{data[platform]['hostname']}.#{data['domain']}"
  if platform_uses_ssh(platform)
    node = { 'name' => hostname,
             'config' => { 'transport' => 'ssh', 'ssh' => { 'user' => 'root', 'password' => 'Qu@lity!', 'host-key-check' => false } },
             'facts' => { 'provisioner' => 'vmpooler', 'platform' => platform },
             'vars'  => vars_hash }
    group_name = 'ssh_nodes'
  else
    node = { 'name' => hostname,
             'config' => { 'transport' => 'winrm', 'winrm' => { 'user' => 'Administrator', 'password' => 'Qu@lity!', 'ssl' => false } },
             'facts' => { 'provisioner' => 'vmpooler', 'platform' => platform },
             'vars' => vars_hash }
    group_name = 'winrm_nodes'
  end
  inventory_full_path = File.join(inventory_location, 'inventory.yaml')
  inventory_hash = get_inventory_hash(inventory_full_path)
  add_node_to_group(inventory_hash, node, group_name)
  File.open(inventory_full_path, 'w') { |f| f.write inventory_hash.to_yaml }
  { status: 'ok', node_name: hostname, node: node }
end

def tear_down(node_name, inventory_location)
  include PuppetLitmus::InventoryManipulation
  vmpooler_hostname = if ENV['VMPOOLER_HOSTNAME'].nil?
                        'vcloud.delivery.puppetlabs.net'
                      else
                        ENV['VMPOOLER_HOSTNAME']
                      end
  uri = URI.parse("http://#{vmpooler_hostname}/vm/#{node_name}")
  token = token_from_fogfile
  headers = { 'X-AUTH-TOKEN' => token } unless token.nil?
  http = Net::HTTP.new(uri.host, uri.port)
  request = if token.nil?
              Net::HTTP::Delete.new(uri.request_uri)
            else
              Net::HTTP::Delete.new(uri.request_uri, headers)
            end
  request.basic_auth @username, @password unless @username.nil?
  http.request(request)
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
vars = params['vars']
raise 'specify a node_name if tearing down' if action == 'tear_down' && node_name.nil?
raise 'specify a platform if provisioning' if action == 'provision' && platform.nil?

begin
  result = provision(platform, inventory_location, vars) if action == 'provision'
  result = tear_down(node_name, inventory_location) if action == 'tear_down'
  puts result.to_json
  exit 0
rescue => e
  puts({ _error: { kind: 'facter_task/failure', msg: e.message } }.to_json)
  exit 1
end
