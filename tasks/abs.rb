#!/usr/bin/env ruby
require 'json'
require 'net/http'
require 'yaml'
require 'puppet_litmus'
require 'etc'
require_relative '../lib/task_helper'

def provision(platform, inventory_location)
  include PuppetLitmus::InventoryManipulation
  uri = URI.parse('https://cinext-abs.delivery.puppetlabs.net/api/v2/request')
  job_id = Process.pid.to_s
  headers = { 'X-AUTH-TOKEN' => token_from_fogfile, 'Content-Type' => 'application/json' }
  payload = { 'resources' => { platform => 1 },
              'job' => { 'id' => job_id,
                         'tags' => { 'user' => Etc.getlogin, 'jenkins_build_url' => 'https://puppet_litmus' } } }
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  request = Net::HTTP::Post.new(uri.request_uri, headers)
  request.body = payload.to_json

  # repeat requests until we get a 200 with a html body
  reply = http.request(request)
  raise "Error: #{reply}: #{reply.message}" unless reply.is_a?(Net::HTTPAccepted) # should be a 202
  now = Time.now
  counter = 1
  loop do
    next if Time.now < now + counter
    reply = http.request(request)
    break if reply.code == '200' # should be a 200
    counter += 1
    raise 'Timeout: unable to get a 200 response in 30 seconds' if counter > 30
  end
  data = JSON.parse(reply.body)

  hostname = data.first['hostname']
  if platform_uses_ssh(platform)
    node = { 'name' => hostname,
             'config' => { 'transport' => 'ssh', 'ssh' => { 'user' => 'root', 'password' => 'Qu@lity!', 'host-key-check' => false } },
             'facts' => { 'provisioner' => 'abs', 'platform' => platform, 'job_id' => job_id } }
    group_name = 'ssh_nodes'
  else
    node = { 'name' => hostname,
             'config' => { 'transport' => 'winrm', 'winrm' => { 'user' => 'Administrator', 'password' => 'Qu@lity!', 'ssl' => false } },
             'facts' => { 'provisioner' => 'abs', 'platform' => platform, 'job_id' => job_id } }
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

  inventory_full_path = File.join(inventory_location, 'inventory.yaml')
  if File.file?(inventory_full_path)
    inventory_hash = inventory_hash_from_inventory_file(inventory_full_path)
    facts = facts_from_node(inventory_hash, node_name)
    platform = facts['platform']
    job_id = facts['job_id']
  end

  uri = URI.parse('https://cinext-abs.delivery.puppetlabs.net/api/v2/return')
  headers = { 'X-AUTH-TOKEN' => token_from_fogfile, 'Content-Type' => 'application/json' }
  payload = { 'job_id' => job_id,
              'hosts' => [{ 'hostname' => node_name, 'type' => platform, 'engine' => 'vmpooler' }] }
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  request = Net::HTTP::Post.new(uri.request_uri, headers)
  request.body = payload.to_json

  reply = http.request(request)
  raise "Error: #{reply}: #{reply.message}" unless reply.code == '200'

  remove_node(inventory_hash, node_name)

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
