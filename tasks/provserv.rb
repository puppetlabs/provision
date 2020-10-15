#!/usr/bin/env ruby
require 'json'
require 'net/http'
require 'yaml'
require 'puppet_litmus'
require_relative '../lib/task_helper'

def default_uri
  URI.parse('https://facade-main-6f3kfepqcq-ew.a.run.app/v1/provision')
end

def platform_to_cloud_request_parameters(platform)
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
  params[:uri] = params[:uri].nil? ? default_uri : URI.parse(params[:uri])
  params
end

# curl -X POST -H "Authorization:bearer ${{ secrets.token }}" https://facade-validation-6f3kfepqcq-ew.a.run.app/v1/provision --data @test_machines.json
# Need a way to retrieve the token locally or from CI secrets? 🤔
# Explodes right now because we don't have a way to grab the GH url
def invoke_cloud_request(params, token = nil)
  uri = params[:uri]
  token = ENV['PROVSERV_TOKEN'] if token.nil?
  puts "NO TOKEN" if token.nil?
  request = Net::HTTP::Post.new(uri)
  request["Authorization"] = "bearer #{token}"
  request.body = JSON.unparse(params.reject{|k| k == :uri})

  require 'pry'; binding.pry;
  req_options = {
    use_ssl: uri.scheme == "https",
  }

  response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
    http.request(request)
  end
end

def provision(platform, inventory_location)
  # include PuppetLitmus::InventoryManipulation
  params = platform_to_cloud_request_parameters(platform)
  invoke_cloud_request(params)
end

def tear_down(node_name, inventory_location)
  include PuppetLitmus::InventoryManipulation
end

params = JSON.parse(STDIN.read)
platform = params['platform']
platform = platform.transform_keys(&:to_sym) if platform.is_a?(Hash)
action = params['action']
node_name = params['node_name']
inventory_location = sanitise_inventory_location(params['inventory'])
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
  result = provision(platform, inventory_location) if action == 'provision'
  result = tear_down(node_name, inventory_location) if action == 'tear_down'
  puts result.to_json
  exit 0
rescue => e
  puts({ _error: { kind: 'facter_task/failure', msg: e.message } }.to_json)
  exit 1
end
