# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'
require_relative '../../tasks/abs.rb'
require 'yaml'

RSpec.shared_context('with_tmpdir') do
  let(:tmpdir) { @tmpdir } # rubocop:disable RSpec/InstanceVariable

  around(:each) do |example|
    Dir.mktmpdir('rspec-provision_test') do |t|
      @tmpdir = t
      example.run
    end
  end
end

describe 'provision::abs' do
  let(:abs) { ABSProvision.new }
  let(:inventory_dir) { "#{tmpdir}/spec/fixtures" }
  let(:inventory_file) { "#{inventory_dir}/litmus_inventory.yaml" }
  let(:empty_inventory_yaml) do
    <<~YAML
      ---
      version: 2
      groups:
      - name: docker_nodes
        targets: []
      - name: ssh_nodes
        targets: []
      - name: winrm_nodes
        targets: []
    YAML
  end

  include_context('with_tmpdir')

  def with_env(env_vars)
    env_vars.each { |k, v| ENV[k] = v }
    yield
  ensure
    env_vars.each { |k, _v| ENV.delete(k) }
  end

  before(:each) do
    FileUtils.mkdir_p(inventory_dir)
  end

  context '.run' do
    it 'handles JSON parameters from stdin' do
      json_input = '{"action":"foo","platform":"bar"}'
      expect($stdin).to receive(:read).and_return(json_input)

      expect { ABSProvision.run }.to(
        raise_error(SystemExit) { |e|
          expect(e.status).to eq(0)
        }.and(
          output("null\n").to_stdout,
        ),
      )
    end

    it 'raises an error when platform not given for provision' do
      expect($stdin).to receive(:read).and_return('{"action":"provision"}')

      expect { ABSProvision.run }.to raise_error(RuntimeError, %r{specify a platform when provisioning})
    end

    it 'raises an error when node_name not given for tear_down'
    it 'raises an error if both node_name and platform are given'
  end

  context 'provision' do
    let(:params) do
      {
        action: 'provision',
        platform: 'redhat-8-x86_64',
        inventory: tmpdir,
      }
    end
    let(:response_body) do
      [
        {
          'type' => 'redhat-8-x86_64',
          'hostname' => 'foo-bar.test',
        },
      ]
    end

    it 'provisions the platform' do
      stub_request(:post, 'https://abs-prod.k8s.infracore.puppet.net/api/v2/request')
        .to_return({ status: 202 }, { status: 200, body: response_body.to_json })

      expect(abs.task(params)).to eq({ status: 'ok', nodes: 1 })

      updated_inventory = YAML.load_file(inventory_file)
      ssh_targets = updated_inventory['groups'].find { |g| g['name'] == 'ssh_nodes' }['targets']
      expect(ssh_targets.size).to eq(1)
      expect(ssh_targets.first.dig('facts', 'platform')).to eq('redhat-8-x86_64')
    end

    it 'targets a different abs host' do
      stub_request(:post, 'https://abs-spec.k8s.infracore.puppet.net/api/v2/request')
        .to_return({ status: 202 }, { status: 200, body: response_body.to_json })

      with_env('ABS_SUBDOMAIN' => 'abs-spec') do
        expect(abs.task(params)).to eq({ status: 'ok', nodes: 1 })
      end
    end

    it 'provision with an existing inventory file' do
      stub_request(:post, 'https://abs-prod.k8s.infracore.puppet.net/api/v2/request')
        .to_return({ status: 202 }, { status: 200, body: response_body.to_json })

      File.write(inventory_file, empty_inventory_yaml)

      expect(abs.task(params)).to eq({ status: 'ok', nodes: 1 })
    end

    it 'raises an error if abs returns error response'
  end

  context 'teardown' do
    let(:params) do
      {
        action: 'tear_down',
        node_name: 'foo-bar.test',
        inventory: tmpdir,
      }
    end
    let(:inventory_yaml) do
      empty = YAML.safe_load(empty_inventory_yaml)
      groups = empty['groups']
      ssh_nodes = groups.find { |g| g['name'] == 'ssh_nodes' }
      ssh_nodes['targets'] << {
        'uri' => 'foo-bar.test',
        'facts' => {
          'platform' => 'redhat-8-x86_64',
          'job_id' => 'a-job-id',
        }
      }
      empty.to_yaml
    end

    before(:each) do
      File.write(inventory_file, inventory_yaml)
    end

    it 'tears down a node' do
      expect(abs).to receive(:token_from_fogfile).and_return('fog-token')
      stub_request(:post, 'https://abs-prod.k8s.infracore.puppet.net/api/v2/return')
        .to_return(status: 200)

      expect(abs.task(params)).to eq({ status: 'ok', removed: ['foo-bar.test'] })
      expect(YAML.load_file(inventory_file)).to eq(YAML.safe_load(empty_inventory_yaml))
    end

    it 'targets a different abs host' do
      expect(abs).to receive(:token_from_fogfile).and_return('fog-token')
      stub_request(:post, 'https://abs-spec.k8s.infracore.puppet.net/api/v2/return')
        .to_return(status: 200)

      with_env('ABS_SUBDOMAIN' => 'abs-spec') do
        expect(abs.task(params)).to eq({ status: 'ok', removed: ['foo-bar.test'] })
      end
    end

    it 'raises an error if abs returns error response'
  end
end
