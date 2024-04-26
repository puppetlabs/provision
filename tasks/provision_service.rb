#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'net/http'
require 'yaml'
require 'etc'
require_relative '../lib/task_helper'
require_relative '../lib/inventory_helper'

# Provision and teardown vms through provision service.
class ProvisionService
  RETRY_COUNT = 3

  def default_uri
    'https://facade-release-6f3kfepqcq-ew.a.run.app/v1/provision'
  end

  def platform_to_cloud_request_parameters(platform, cloud, region, zone)
    case platform
    when String
      { cloud: cloud, region: region, zone: zone, images: [platform] }
    when Array
      { cloud: cloud, region: region, zone: zone, images: platform }
    else
      platform[:cloud] = cloud unless cloud.nil?
      platform[:images] = [platform[:images]] if platform[:images].is_a?(String)
      platform
    end
  end

  # curl -X POST https://facade-validation-6f3kfepqcq-ew.a.run.app/v1/provision --data @test_machines.json
  def invoke_cloud_request(params, uri, job_url, verb, retry_attempts)
    headers =  {
      'Accept' => 'application/json',
      'Content-Type' => 'application/json'
    }

    case verb.downcase
    when 'post'
      request = Net::HTTP::Post.new(uri, headers)
      machines = []
      machines << params
      request.body = if job_url
                       { url: job_url, VMs: machines }.to_json
                     else
                       { github_token: ENV.fetch('GITHUB_TOKEN', nil), VMs: machines }.to_json
                     end
    when 'delete'
      request = Net::HTTP::Delete.new(uri, headers)
      request.body = { uuid: params }.to_json
    else
      raise StandardError "Unknown verb: '#{verb}'"
    end

    if job_url
      File.open('request.json', 'wb') do |f|
        f.write(request.body)
      end
    end

    req_options = {
      use_ssl: uri.scheme == 'https',
      read_timeout: 60 * 5, # timeout reads after 5 minutes - that's longer than the backend service would keep the request open
      max_retries: retry_attempts # retry up to 5 times before throwing an error
    }

    response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
      http.request(request)
    end
    if response.code == '200'
      response.body
    else
      begin
        body = JSON.parse(response.body)
        body_json = true
      rescue JSON::ParserError
        body = response.body
        body_json = false
      end
      puts({ _error: { kind: 'provision_service/service_error', msg: 'provision service returned an error', code: response.code, body: body, body_json: body_json } }.to_json)
      exit 1
    end
  end

  def provision(platform, inventory, vars, retry_attempts)
    # Call the provision service with the information necessary and write the inventory file locally

    if ENV['GITHUB_RUN_ID']
      job_url = ENV['GITHUB_URL'] || "https://api.github.com/repos/#{ENV.fetch('GITHUB_REPOSITORY', nil)}/actions/runs/#{ENV['GITHUB_RUN_ID']}"
    else
      puts 'Using GITHUB_TOKEN as no GITHHUB_RUN_ID found'
    end
    uri = URI.parse(ENV['SERVICE_URL'] || default_uri)
    cloud = ENV.fetch('CLOUD', nil)
    region = ENV.fetch('REGION', nil)
    zone = ENV.fetch('ZONE', nil)
    if job_url.nil? && vars
      data = JSON.parse(vars.tr(';', ','))
      job_url = data['job_url']
    end
    currnet_retry_count = 0
    begin
      params = platform_to_cloud_request_parameters(platform, cloud, region, zone)
      response = invoke_cloud_request(params, uri, job_url, 'post', retry_attempts)
      response_hash = YAML.safe_load(response)
      # Knock the response for validity to make sure return payload is expected.
      # Have seen multiple occurances of nil:NilClass error where the response code is 200 but return payload is empty
      raise if response_hash.nil? || response_hash.empty?
    rescue StandardError => e
      currnet_retry_count += 1
      raise e if currnet_retry_count >= RETRY_COUNT

      puts "Failed while provisioning the resource with response :\n #{response_hash}\nHence retrying #{currnet_retry_count} of #{RETRY_COUNT}"
      retry
    end

    unless vars.nil?
      var_hash = YAML.safe_load(vars)
    end

    response_hash['groups'].each do |bg|
      bg['targets'].each do |trgts|
        trgts['vars'] = var_hash if var_hash
        inventory.add(trgts, bg['name'])
      end
    end
    inventory.save

    {
      status: 'ok',
      node_name: platform,
      target_names: response_hash['groups']&.each { |g| g['targets'] }&.map { |t| t['uri'] }&.flatten&.uniq
    }
  end

  def tear_down(node_name, inventory, _vars, retry_attempts)
    # remove all provisioned resources
    uri = URI.parse(ENV['SERVICE_URL'] || default_uri)

    node = inventory.lookup(name: node_name)
    facts = node['facts']
    job_id = facts['uuid']
    response = invoke_cloud_request(job_id, uri, '', 'delete', retry_attempts)
    response.to_json
  end

  def self.run
    params = JSON.parse($stdin.read)
    params.transform_keys!(&:to_sym)
    action, node_name, platform, vars, retry_attempts, inventory_location = params.values_at(:action, :node_name, :platform, :vars, :retry_attempts, :inventory)
    inventory = InventoryHelper.open(inventory_location)

    runner = new
    begin
      case action
      when 'provision'
        raise 'specify a platform when provisioning' if platform.to_s.empty?

        result = runner.provision(platform, inventory, vars, retry_attempts)
      when 'tear_down'
        raise 'specify a node_name when tearing down' if node_name.nil?

        result = runner.tear_down(node_name, inventory, vars, retry_attempts)
      else
        result = { _error: { kind: 'provision_service/argument_error', msg: "Unknown action '#{action}'" } }
      end
      puts result.to_json
      exit 0
    rescue StandardError => e
      puts({ _error: { kind: 'provision_service/failure', msg: e.message, details: { backtrace: e.backtrace } } }.to_json)
      exit 1
    end
  end
end

ProvisionService.run if __FILE__ == $PROGRAM_NAME
