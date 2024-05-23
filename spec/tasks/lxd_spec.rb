# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'
require_relative '../../tasks/lxd'
require 'yaml'

RSpec::Matchers.define_negated_matcher :not_raise_error, :raise_error

RSpec.shared_context('with tmpdir') do
  let(:tmpdir) { @tmpdir } # rubocop:disable RSpec/InstanceVariable

  around(:each) do |example|
    Dir.mktmpdir('rspec-provision_test') do |t|
      @tmpdir = t
      example.run
    end
  end
end

describe 'provision::lxd' do
  let(:lxd) { LXDProvision.new }

  let(:inventory_dir) { "#{tmpdir}/spec/fixtures" }
  let(:inventory_file) { "#{inventory_dir}/litmus_inventory.yaml" }
  let(:inventory_hash) { get_inventory_hash(inventory_file) }

  let(:provision_input) do
    {
      action: 'provision',
      platform: 'images:foobar/1',
      inventory: tmpdir
    }
  end
  let(:tear_down_input) do
    {
      action: 'tear_down',
      node_name: container_id,
      inventory: tmpdir
    }
  end

  let(:lxd_config_show) do
    <<-YAML
    architecture: x86_64
    config:
      image.architecture: amd64
      image.description: Almalinux 9 amd64 (20240515_23:08)
      image.os: Almalinux
      image.release: "9"
      image.requirements.cdrom_agent: "true"
      image.serial: "20240515_23:08"
      image.type: disk-kvm.img
      image.variant: default
      limits.cpu: "2"
      limits.memory: 4GB
      raw.idmap: |-
        uid 1000 1000
        gid 1000 1000
      volatile.apply_template: create
      volatile.base_image: 980e4586bcb618732801ee5ef36bbb7c11beaad4a56862938701354c18b6e706
      volatile.cloud-init.instance-id: dbecd5bc-252b-4d4a-a7c5-9fd4c5e39be0
      volatile.eth0.hwaddr: 00:16:3e:96:41:fb
      volatile.uuid: ccbca107-16bb-450e-9afe-d77e4d100f4b
      volatile.uuid.generation: ccbca107-16bb-450e-9afe-d77e4d100f4b
    devices:
      eth0:
        name: eth0
        network: incusbr-1000
        type: nic
      root:
        path: /
        pool: local
        type: disk
    ephemeral: false
    profiles:
    - default
    stateful: false
    description: ""
    YAML
  end

  let(:lxd_remote) { 'fake' }
  let(:lxd_flags) { [] }
  let(:lxd_platform) { nil }
  let(:container_id) { lxd_init_output }
  let(:lxd_init_output) { 'random-host' }

  let(:provision_output) do
    {
      status: 'ok',
      node_name: container_id,
      node: {
        uri: container_id,
        config: {
          transport: 'lxd',
          lxd: {
            remote: lxd_remote,
            'shell-command': 'sh -lc'
          }
        },
        facts: {
          provisioner: 'lxd',
          container_id: container_id,
          platform: lxd_platform
        }
      }
    }
  end

  let(:tear_down_output) do
    {
      status: 'ok',
    }
  end

  include_context('with tmpdir')

  before(:each) do
    FileUtils.mkdir_p(inventory_dir)
  end

  describe '.run' do
    let(:task_input) { {} }
    let(:imposter) { instance_double('LXDProvision') }

    task_tests = [
      [ { action: 'provision', platform: 'test' }, 'success', true ],
      [ { action: 'provision', platform: 'test', vm: true }, 'success', true ],
      [ { action: 'provision', node_name: 'test' }, 'do not specify node_name', false ],
      [ { action: 'provision' }, 'platform required', false ],
      [ { action: 'tear_down', node_name: 'test' }, 'success', true ],
      [ { action: 'tear_down' }, 'node_name required', false ],
      [ { action: 'tear_down', platform: 'test' }, 'do not specify platform', false ],
    ]

    task_tests.each do |v|
      it "expect arguments '#{v[0]}' return '#{v[1]}'#{v[2] ? '' : ' and raise error'}" do
        allow(LXDProvision).to receive(:new).and_return(imposter)
        allow(imposter).to receive(:task).and_return(v[1])
        allow($stdin).to receive(:read).and_return(v[0].to_json)
        if v[2]
          expect { LXDProvision.run }.to output(%r{#{v[1]}}).to_stdout
        else
          expect { LXDProvision.run }.to output(%r{#{v[1]}}).to_stdout.and raise_error(SystemExit)
        end
      end
    end
  end

  describe '.task' do
    context 'action=provision' do
      let(:lxd_platform) { provision_input[:platform] }

      before(:each) do
        expect(lxd).to receive(:run_local_command)
          .with('lxc -q remote get-default').and_return(lxd_remote)
        expect(lxd).to receive(:run_local_command)
          .with("lxc -q create #{lxd_platform} #{lxd_remote}: #{lxd_flags.join(' ')}").and_return(lxd_init_output)
        expect(lxd).to receive(:run_local_command)
          .with("lxc -q config show #{lxd_remote}:#{container_id} -e").and_return(lxd_config_show)
        if lxd_config_show.match?(%r{image\.requirements\.cdrom_agent:.*true})
          expect(lxd).to receive(:run_local_command)
            .with("lxc -q config device add #{lxd_remote}:#{container_id} agent disk source=agent:config").and_return(lxd_config_show)
        end
        expect(lxd).to receive(:run_local_command)
          .with("lxc -q start #{lxd_remote}:#{container_id}").and_return(lxd_init_output)
      end

      it 'provisions successfully' do
        expect(lxd).to receive(:run_local_command)
          .with("lxc -q exec #{lxd_remote}:#{container_id} uptime")

        LXDProvision.new.add_node_to_group(inventory_hash, JSON.parse(provision_output[:node].to_json), 'lxd_nodes')

        expect(File).to receive(:write).with(inventory_file, JSON.parse(inventory_hash.to_json).to_yaml)
        expect(lxd.task(**provision_input)).to eq(provision_output)
      end

      it 'when retries=0 try once but ignore the raised error' do
        provision_input[:retries] = 0

        expect(lxd).to receive(:run_local_command)
          .with("lxc -q exec #{lxd_remote}:#{container_id} uptime").and_raise(StandardError)

        expect(lxd.task(**provision_input)).to eq(provision_output)
      end

      it 'max retries then deletes the instance' do
        expect(lxd).to receive(:run_local_command)
          .exactly(3).times
          .with("lxc -q exec #{lxd_remote}:#{container_id} uptime").and_raise(StandardError)
        expect(lxd).to receive(:run_local_command)
          .with("lxc -q delete #{lxd_remote}:#{container_id} -f")

        expect { lxd.task(**provision_input) }.to raise_error(StandardError, %r{Giving up waiting for #{lxd_remote}:#{container_id}})
      end
    end

    context 'action=tear_down' do
      before(:each) do
        File.write(inventory_file, JSON.parse(inventory_hash.to_json).to_yaml)
      end

      it 'tears down successfully' do
        expect(lxd).to receive(:run_local_command)
          .with("lxc -q delete #{lxd_remote}:#{container_id} -f")

        LXDProvision.new.add_node_to_group(inventory_hash, JSON.parse(provision_output[:node].to_json), 'lxd_nodes')
        File.write(inventory_file, inventory_hash.to_yaml)

        expect(lxd.task(**tear_down_input)).to eq(tear_down_output)
      end

      it 'expect to raise error if no inventory' do
        File.delete(inventory_file)
        expect { lxd.task(**tear_down_input) }.to raise_error(StandardError, %r{Unable to find})
      end

      it 'expect to raise error if node_name not in inventory' do
        expect { lxd.task(**tear_down_input) }.to raise_error(StandardError, %r{node_name #{container_id} not found in inventory})
      end
    end
  end
end
