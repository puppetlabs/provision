#!/usr/bin/env ruby
require 'json'
require 'net/http'
require 'yaml'
require 'puppet_litmus'
require 'etc'
require_relative '../lib/task_helper'
include PuppetLitmus::InventoryManipulation

def default_uri
  URI.parse('https://facade-main-6f3kfepqcq-ew.a.run.app/v1/provision')
end

def platform_to_cloud_request_parameters(platform, _job_url)
  params = case platform
           when String
             { cloud: 'gcp', images: [platform] }
           when Array
             { cloud: 'gcp', images: platform }
           else
             platform[:cloud] = 'gcp' if platform[:cloud].nil?
             platform[:images] = [platform[:images]] if platform[:images].is_a?(String)
             platform
           end
  params
end

# curl -X POST https://facade-validation-6f3kfepqcq-ew.a.run.app/v1/provision --data @test_machines.json
def invoke_cloud_request(params, uri, job_url, verb)
  case verb.downcase
  when 'post'
    request = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
    machines = []
    machines << params
    request.body = { url: job_url, VMs: machines }.to_json
  when 'delete'
    request = Net::HTTP::Delete.new(uri)
    request.body = { uuid: params }.to_json
  else
    raise StandardError 'Unknown verb'
  end

  File.open('request.json', 'wb') do |f|
    f.write(request.body)
  end

  req_options = {
    use_ssl: uri.scheme == 'https',
    read_timeout: 500,
  }

  response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
    http.request(request)
  end
  response.body
end

def provision(platform, inventory_location, vars)
  # Call the provision service with the information necessary and write the inventory file locally

  job_url = ENV['GITHUB_URL']
  uri = ENV['SERVICE_URL']
  uri = default_uri if uri.nil?
  if job_url.nil?
    data = JSON.parse(vars.tr(';', ','))
    job_url = data['job_url']
  end
  inventory_full_path = File.join(inventory_location, 'inventory.yaml')

  params = platform_to_cloud_request_parameters(platform, job_url)
  response = invoke_cloud_request(params, uri, job_url, 'post')
  if File.file?(inventory_full_path)
    inventory_hash = inventory_hash_from_inventory_file(inventory_full_path)
    response_hash = YAML.safe_load(response)

    inventory_hash['groups'].each do |g|
      response_hash['groups'].each do |bg|
        if g['name'] == bg['name']
          g['targets'] = g['targets'] + bg['targets']
        end
      end
    end

    File.open(inventory_full_path, 'w') { |f| f.write inventory_hash.to_yaml }
  else
    File.open('inventory.yaml', 'wb') do |f|
      f.write(response)
    end
  end
  { status: 'ok', node_name: platform }
end

def tear_down(platform, inventory_location, _vars)
  # remove all provisioned resources
  uri = ENV['SERVICE_URL']
  uri = default_uri if uri.nil?

  inventory_full_path = File.join(inventory_location, 'inventory.yaml')
  # rubocop:disable Style/GuardClause
  if File.file?(inventory_full_path)
    inventory_hash = inventory_hash_from_inventory_file(inventory_full_path)
    facts = facts_from_node(inventory_hash, platform)
    job_id = facts['uuid']
    response = invoke_cloud_request(job_id, uri, '', 'delete')
    return response.to_json
  end
  # rubocop:enable Style/GuardClause
end

params = JSON.parse(STDIN.read)
platform = params['platform']
action = params['action']
vars = params['vars']
node_name = params['node_name']
inventory_location = sanitise_inventory_location(params['inventory'])
raise 'specify a node_name when tearing down' if action == 'tear_down' && node_name.nil?
raise 'specify a platform when provisioning' if action == 'provision' && platform.nil?

begin
  result = provision(platform, inventory_location, vars) if action == 'provision'
  result = tear_down(node_name, inventory_location, vars) if action == 'tear_down'
  puts result.to_json
  exit 0
rescue => e
  puts({ _error: { kind: 'facter_task/failure', msg: e.message } }.to_json)
  exit 1
end
