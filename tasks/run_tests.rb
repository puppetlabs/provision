#!/usr/bin/env ruby
# frozen_string_literal: true

require 'puppet_litmus'
require_relative '../lib/task_helper'

def run_tests(sut, test_path, format)
  test = "bundle exec rspec #{test_path} --format #{format}"
  options = {
    env: {
      'TARGET_HOST' => sut
    }
  }
  env = options[:env].nil? ? {} : options[:env]
  stdout, stderr, status = Open3.capture3(env, test)
  raise "status: 'not ok'\n stdout: #{stdout}\n stderr: #{stderr}" unless status.to_i.zero?

  { status: 'ok', result: stdout }
end

params = JSON.parse($stdin.read)
sut = params['sut']
test_path = if params['test_path'].nil?
              './spec/acceptance/'
            else
              params['test_path']
            end
format = params['format']

begin
  result = run_tests(sut, test_path, format)
  puts result.to_json
  exit 0
rescue StandardError => e
  puts({ _error: { kind: 'run_tests/failure', msg: e.message } }.to_json)
  exit 1
end
