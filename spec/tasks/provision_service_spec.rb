# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'
require_relative '../../tasks/provision_service'

ENV['GITHUB_RUN_ID'] = '1234567890'
ENV['GITHUB_URL'] = 'https://api.github.com/repos/puppetlabs/puppetlabs-iis/actions/runs/1234567890'

describe 'ProvisionService' do
  describe '.run' do
    context 'when inputs are invalid' do
      it 'return exception' do
        json_input = '{}'
        allow($stdin).to receive(:read).and_return(json_input)

        expect { ProvisionService.run }.to(
          raise_error(SystemExit) { |e|
            expect(e.status).to eq(0)
          }.and(
            output(%r{Unknown action}).to_stdout,
          ),
        )
      end

      it 'return exception about invalid action' do
        json_input = '{"action":"foo","platform":"bar"}'
        allow($stdin).to receive(:read).and_return(json_input)

        expect { ProvisionService.run }.to(
          raise_error(SystemExit) { |e|
            expect(e.status).to eq(0)
          }.and(
            output(%r{Unknown action 'foo'}).to_stdout,
          ),
        )
      end

      it 'return exception for missing platform' do
        json_input = '{"action":"provision"}'
        allow($stdin).to receive(:read).and_return(json_input)

        expect { ProvisionService.run }.to(
          raise_error(SystemExit) { |e|
            expect(e.status).to eq(1)
          }.and(
            output(%r{specify a platform when provisioning}).to_stdout,
          ),
        )
      end

      it 'return exception for missing node_name' do
        json_input = '{"action":"tear_down"}'
        allow($stdin).to receive(:read).and_return(json_input)

        expect { ProvisionService.run }.to(
          raise_error(SystemExit) { |e|
            expect(e.status).to eq(1)
          }.and(
            output(%r{specify a node_name when tearing down}).to_stdout,
          ),
        )
      end
    end

    it 'calls provision and exits 0' do
      allow($stdin).to receive(:read).and_return('{"action":"provision","platform":"centos-8"}')
      runner = ProvisionService.new
      allow(ProvisionService).to receive(:new).and_return(runner)
      expect(runner).to receive(:provision).with('centos-8', instance_of(InventoryHelper), nil, nil).and_return({ status: 'ok', node_name: 'centos-8' })
      expect { ProvisionService.run }.to raise_error(SystemExit) { |e| expect(e.status).to eq(0) }
    end

    it 'prints the service_error details and exits 1 when the service returns an error' do
      allow($stdin).to receive(:read).and_return('{"action":"tear_down","node_name":"some-node"}')
      runner = ProvisionService.new
      allow(ProvisionService).to receive(:new).and_return(runner)
      allow(runner).to receive(:tear_down).and_raise(ProvisionService::ServerError.new('500', { 'error' => 'server error' }, true))
      expect { ProvisionService.run }.to(
        raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
          .and(output(include('"kind":"provision_service/service_error"', '"code":"500"', '"body":{"error":"server error"}', '"body_json":true')).to_stdout),
      )
    end

    it 'calls tear_down and exits 0' do
      allow($stdin).to receive(:read).and_return('{"action":"tear_down","node_name":"some-node"}')
      runner = ProvisionService.new
      allow(ProvisionService).to receive(:new).and_return(runner)
      allow(runner).to receive(:tear_down).and_return('{}')
      expect { ProvisionService.run }.to raise_error(SystemExit) { |e| expect(e.status).to eq(0) }
    end
  end

  describe '#provision' do
    let(:inventory) { InventoryHelper.open("#{Dir.pwd}/litmus_inventory.yaml") }
    let(:vars) { nil }
    let(:platform) { 'centos-8' }
    let(:retry_attempts) { 8 }
    let(:response_body) do
      {
        'groups' => [
          'targets' => {
            'uri' => '127.0.0.1'
          },
        ]
      }
    end
    let(:provision_service) { ProvisionService.new }
    let(:service_url) { 'https://facade-release-6f3kfepqcq-ew.a.run.app/v1/provision' }

    before(:each) do
      allow(provision_service).to receive(:sleep)
      allow(provision_service).to receive(:warn)
    end

    context 'when response is empty' do
      it 'return exception' do
        stub_request(:post, 'https://facade-release-6f3kfepqcq-ew.a.run.app/v1/provision')
          .with(
            body: '{"url":"https://api.github.com/repos/puppetlabs/puppetlabs-iis/actions/runs/1234567890","VMs":[{"cloud":null,"region":null,"zone":null,"images":["centos-8"]}]}',
            headers: {
              'Accept' => 'application/json',
              'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
              'Content-Type' => 'application/json',
              'Host' => 'facade-release-6f3kfepqcq-ew.a.run.app',
              'User-Agent' => 'Ruby'
            },
          )
          .to_return(status: 200, body: '', headers: {})
        expect { provision_service.provision(platform, inventory, vars, retry_attempts) }.to raise_error(RuntimeError)
      end
    end

    context 'when successive retry success' do
      it 'return valid response' do
        stub_request(:post, 'https://facade-release-6f3kfepqcq-ew.a.run.app/v1/provision')
          .with(
            body: '{"url":"https://api.github.com/repos/puppetlabs/puppetlabs-iis/actions/runs/1234567890","VMs":[{"cloud":null,"region":null,"zone":null,"images":["centos-8"]}]}',
            headers: {
              'Accept' => 'application/json',
              'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
              'Content-Type' => 'application/json',
              'Host' => 'facade-release-6f3kfepqcq-ew.a.run.app',
              'User-Agent' => 'Ruby'
            },
          )
          .to_return(status: 200, body: '', headers: {})
        expect { provision_service.provision(platform, inventory, vars, retry_attempts) }.to raise_error(RuntimeError)
        stub_request(:post, 'https://facade-release-6f3kfepqcq-ew.a.run.app/v1/provision')
          .with(
            body: '{"url":"https://api.github.com/repos/puppetlabs/puppetlabs-iis/actions/runs/1234567890","VMs":[{"cloud":null,"region":null,"zone":null,"images":["centos-8"]}]}',
            headers: {
              'Accept' => 'application/json',
              'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
              'Content-Type' => 'application/json',
              'Host' => 'facade-release-6f3kfepqcq-ew.a.run.app',
              'User-Agent' => 'Ruby'
            },
          )
          .to_return(status: 200, body: response_body.to_json, headers: {})
        allow(File).to receive(:open)
        expect(provision_service.provision(platform, inventory, vars, retry_attempts)[:status]).to eq('ok')
      end
    end

    context 'when response is valid' do
      it 'return valid response' do
        stub_request(:post, 'https://facade-release-6f3kfepqcq-ew.a.run.app/v1/provision')
          .with(
            body: '{"url":"https://api.github.com/repos/puppetlabs/puppetlabs-iis/actions/runs/1234567890","VMs":[{"cloud":null,"region":null,"zone":null,"images":["centos-8"]}]}',
            headers: {
              'Accept' => 'application/json',
              'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
              'Content-Type' => 'application/json',
              'Host' => 'facade-release-6f3kfepqcq-ew.a.run.app',
              'User-Agent' => 'Ruby'
            },
          )
          .to_return(status: 200, body: response_body.to_json, headers: {})

        allow(File).to receive(:open)
        expect(provision_service.provision(platform, inventory, vars, retry_attempts)[:status]).to eq('ok')
      end
    end

    context 'when the service returns a 5xx and then succeeds' do
      it 'retries with a backoff and returns a valid response' do
        stub_request(:post, service_url)
          .to_return({ status: 500, body: '{"error":"server error"}' }, { status: 200, body: response_body.to_json })
        allow(File).to receive(:open)
        expect(provision_service).to receive(:sleep).once.with(be_between(30, 45))
        expect(provision_service).to receive(:warn).with(%r{attempt 1 of 4 failed: provision service returned an error \(HTTP 500\)})

        expect(provision_service.provision(platform, inventory, vars, retry_attempts)[:status]).to eq('ok')
        expect(a_request(:post, service_url)).to have_been_made.twice
      end
    end

    context 'when the service keeps returning a 5xx' do
      it 'gives up after RETRY_COUNT attempts with exponential backoff' do
        stub_request(:post, service_url).to_return(status: 503, body: 'Service Unavailable')
        allow(File).to receive(:open)
        expect(provision_service).to receive(:sleep).with(be_between(30, 45)).ordered
        expect(provision_service).to receive(:sleep).with(be_between(60, 90)).ordered
        expect(provision_service).to receive(:sleep).with(be_between(120, 180)).ordered

        expect { provision_service.provision(platform, inventory, vars, retry_attempts) }.to raise_error(ProvisionService::ServerError) { |e|
          expect(e.code).to eq('503')
          expect(e.attempts).to eq(4)
        }
        expect(a_request(:post, service_url)).to have_been_made.times(4)
      end
    end

    context 'when the service returns a 4xx' do
      it 'fails without retrying' do
        stub_request(:post, service_url).to_return(status: 400, body: '{"error":"bad image"}')
        allow(File).to receive(:open)
        expect(provision_service).not_to receive(:sleep)

        expect { provision_service.provision(platform, inventory, vars, retry_attempts) }.to raise_error(ProvisionService::ServiceError) { |e|
          expect(e).not_to be_a(ProvisionService::ServerError)
          expect(e.attempts).to eq(1)
        }
        expect(a_request(:post, service_url)).to have_been_made.once
      end
    end
  end

  describe '#retry_delay' do
    let(:svc) { ProvisionService.new }

    it 'doubles the base delay on each attempt and adds up to 50% jitter' do
      expect(svc.retry_delay(1)).to be_between(30, 45)
      expect(svc.retry_delay(2)).to be_between(60, 90)
      expect(svc.retry_delay(3)).to be_between(120, 180)
    end
  end

  describe '#platform_to_cloud_request_parameters' do
    let(:svc) { ProvisionService.new }

    it 'handles an Array platform' do
      result = svc.platform_to_cloud_request_parameters(['centos-8', 'ubuntu-20'], 'aws', 'us-east-1', 'a')
      expect(result[:images]).to eq(['centos-8', 'ubuntu-20'])
    end

    it 'handles a Hash platform and wraps String images in an Array' do
      platform = { cloud: 'gcp', images: 'centos-8' }
      result = svc.platform_to_cloud_request_parameters(platform, nil, nil, nil)
      expect(result[:images]).to eq(['centos-8'])
    end

    it 'handles a Hash platform and overrides the cloud' do
      platform = { images: ['centos-8'] }
      result = svc.platform_to_cloud_request_parameters(platform, 'aws', nil, nil)
      expect(result[:cloud]).to eq('aws')
    end
  end

  describe '#invoke_cloud_request' do
    let(:svc) { ProvisionService.new }
    let(:uri) { URI.parse('https://facade-release-6f3kfepqcq-ew.a.run.app/v1/provision') }

    it 'sends a DELETE request' do
      stub_request(:delete, uri.to_s).to_return(status: 200, body: '{}')
      result = svc.invoke_cloud_request('some-uuid', uri, nil, 'delete', 0)
      expect(result).to eq('{}')
    end

    it 'raises a ServerError with parsed JSON error details on a 5xx response' do
      stub_request(:post, uri.to_s).to_return(status: 500, body: '{"error":"server error"}')
      expect { svc.invoke_cloud_request({}, uri, nil, 'post', 0) }.to raise_error(ProvisionService::ServerError) { |e|
        expect(e.code).to eq('500')
        expect(e.body).to eq({ 'error' => 'server error' })
        expect(e.body_json).to be(true)
      }
    end

    it 'raises a ServerError with the raw body on a non-JSON 5xx response' do
      stub_request(:post, uri.to_s).to_return(status: 500, body: 'Internal Server Error')
      expect { svc.invoke_cloud_request({}, uri, nil, 'post', 0) }.to raise_error(ProvisionService::ServerError) { |e|
        expect(e.body).to eq('Internal Server Error')
        expect(e.body_json).to be(false)
      }
    end

    it 'raises a plain ServiceError on a 4xx response' do
      stub_request(:post, uri.to_s).to_return(status: 404, body: '{"error":"not found"}')
      expect { svc.invoke_cloud_request({}, uri, nil, 'post', 0) }.to raise_error(ProvisionService::ServiceError) { |e|
        expect(e).not_to be_a(ProvisionService::ServerError)
      }
    end
  end
end
