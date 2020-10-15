#!/usr/bin/env ruby
require 'json'
require 'net/http'
require 'yaml'
require 'puppet_litmus'
require 'etc'
require_relative '../lib/task_helper'

def provision(platform, inventory_location, vars)
  #Call the provision service with the information necessary and write the inventory file locally
  {status: 'ok', node_name: vars, node: platform, invloc: inventory_location, v: vars}
end

def tear_down(platform, inventory_location, vars)
  #remove all provisioned resources
end

params = JSON.parse(STDIN.read)
platform = params['platform']
action = params['action']
vars = params['vars']
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
