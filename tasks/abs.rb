#!/usr/bin/env ruby
require 'json'
require 'net/http'
require 'yaml'
require 'solid_waffle'
require 'pry'
require 'etc'

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
  token = contents.dig(:default, :abs_token)
  token
end

def provision(platform, inventory_location)
  include SolidWaffle
  binding.pry()
  uri = URI.parse('https://cinext-abs.delivery.puppetlabs.net/api/v2/request')
  headers = { 'X-AUTH-TOKEN' => token_from_fogfile, 'Content-Type' => 'application/json' }
  payload = { 'resources' => { platform => 1 },
              'job' => { 'id' => Process.pid.to_s,
                         'tags' => { 'user' => Etc.getlogin, 'jenkins_build_url' => 'https://solid-waffle' } } }
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
    if Time.now < now + counter
      next
    else
      reply = http.request(request)
      break if reply.code == '200' # should be a 200
    end
    counter += 1
    raise 'Timeout: unable to get a 200 response in 30 seconds' if counter > 30
  end
  data = JSON.parse(reply.body)

  hostname = data.first['hostname']
  if platform_uses_ssh(platform)
    node = { 'name' => hostname,
             'config' => { 'transport' => 'ssh', 'ssh' => { 'user' => 'root', 'password' => 'Qu@lity!', 'host-key-check' => false } },
             'facts' => { 'provisioner' => 'abs', 'platform' => platform } }
    group_name = 'ssh_nodes'
  else
    node = { 'name' => hostname,
             'config' => { 'transport' => 'winrm', 'winrm' => { 'user' => 'Administrator', 'password' => 'Qu@lity!', 'ssl' => false } },
             'facts' => { 'provisioner' => 'abs', 'platform' => platform } }
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
