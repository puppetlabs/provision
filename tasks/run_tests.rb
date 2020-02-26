#!/usr/bin/env ruby
# frozen_string_literal: true

require 'puppet_litmus'
require_relative '../lib/task_helper'

include Provision::TaskHelper

def run_tests(sut, test_path)
  test = "bundle exec rspec #{test_path} --format progress"
  options = {
    env: {
      'TARGET_HOST' => sut,
    },
  }
  env = options[:env].nil? ? {} : options[:env]
  stdout, stderr, status = Open3.capture3(env, test)
  raise "status: 'not ok'\n stdout: #{stdout}\n stderr: #{stderr}" unless status.to_i.zero?
  { status: 'ok', result: stdout }
end

params = JSON.parse(STDIN.read)
sut = params['sut']
test_path = if params['test_path'].nil?
              './spec/acceptance/'
            else
              params['test_path']
            end
begin
  result = run_tests(sut, test_path)
  puts result.to_json
  exit 0
rescue => e
  puts({ _error: { kind: 'run_tests/failure', msg: e.message } }.to_json)
  exit 1
end
