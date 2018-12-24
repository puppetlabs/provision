#!/usr/bin/env ruby
require 'json'
require 'net/http'
require 'yaml'
require 'solid_waffle'
require 'pry'

def platform_uses_ssh(platform)
  uses_ssh = if platform !~ %r{win-}
               true
             else
               false
             end
  uses_ssh
end

def token_from_fogfile
  fog_file = File.join(Dir.home, '.fog')
  raise "Cannot file fog file at #{fog_file}" unless File.file?(fog_file)
  contents = YAML.load_file(fog_file)
  token = contents.dig(:default, :vmpooler_token)
  token
end

def provision(platform, inventory_location)
  include SolidWaffle
  uri = URI.parse("http://vcloud.delivery.puppetlabs.net/vm/#{platform}")
  headers = { 'X-AUTH-TOKEN' => token_from_fogfile }

  http = Net::HTTP.new(uri.host, uri.port)
  request = Net::HTTP::Post.new(uri.request_uri, headers)
  reply = http.request(request)
  raise "Error: #{reply}: #{reply.message}" unless reply.is_a?(Net::HTTPSuccess)

  data = JSON.parse(reply.body)
  raise "VMPooler is not ok: #{data.inspect}" unless data['ok'] == true

  hostname = "#{data[platform]['hostname']}.#{data['domain']}"
  if platform_uses_ssh(platform)
    node = { 'name' => hostname,
             'config' => { 'transport' => 'ssh', 'ssh' => { 'host-key-check' => false } },
             'facts' => { 'provisioner' => 'abs' } }
    group_name = 'ssh_nodes'
  else
    node = { 'name' => hostname,
             'config' => { 'transport' => 'winrm', 'winrm' => { 'user' => 'Administrator', 'password' => 'Qu@lity!', 'ssl' => false } },
             'facts' => { 'provisioner' => 'abs' } }
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
  { status: 'ok', node_name: hostname }
end

def tear_down(node_name, inventory_location)
  include SolidWaffle
  uri = URI.parse("http://vcloud.delivery.puppetlabs.net/vm/#{node_name}")
  headers = { 'X-AUTH-TOKEN' => token_from_fogfile }
  http = Net::HTTP.new(uri.host, uri.port)
  request = Net::HTTP::Delete.new(uri.request_uri, headers)
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
