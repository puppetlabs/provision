#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require_relative '../lib/task_helper.rb'
require_relative '../lib/terraform.rb'

require 'pp'

include Provision::TaskHelper

params = JSON.parse(STDIN.read)
STDERR.puts params
platform = params['platform']
action = params['action']
node_name = params['node_name']
params['inventory'] = sanitise_inventory_location(params['inventory'])

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
  terraform = Provision::Terraform::GCP.new(params)
  STDERR.puts "[DEBUG] #{terraform}"
  result = case action
           when 'provision'
             terraform.provision(params)
           when 'tear_down'
             terraform.tear_down(params)
           else
             raise 'action only supports provision or teardown'
           end
  puts result.to_json
  exit 0
rescue => e
  STDERR.puts "[ERROR] #{e.backtrace.join("\n")}"
  puts({ _error: { kind: 'facter_task/failure', msg: e.message } }.to_json)
  e.backtrace.each do |b|
    puts({ _error: { kind: 'facter_task/failure', msg: b } }.to_json)
  end
  exit 1
end
