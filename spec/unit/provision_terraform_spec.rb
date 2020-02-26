# frozen_string_literal: true

require 'fileutils'
require 'terraform'

describe 'Provision::Terraform::Base' do
  let(:tmpdir) { Dir.mktmpdir }

  let(:terraform) { Provision::Terraform::Base }

  describe '#initialize' do
    it 'creates an instance with all defaults' do
      tf = terraform.new
      expect(tf).to be_an_instance_of(terraform)
    end

    it 'accepts a parameters hash' do
      params = {
        'dir' => tmpdir,
        'inventory' => tmpdir,
      }
      tf = terraform.new(params)
      expect(tf).to be_an_instance_of(terraform)
    end
  end

  describe '#tear_down' do
    let(:params) do
      {
        'dir' => tmpdir,
        'inventory' => tmpdir,
      }
    end
    let(:tf) { terraform.new(params) }

    after(:each) do
      FileUtils.remove_entry(tmpdir) if File.exist?(tmpdir)
    end

    it 'executes terraform destroy' do
      cmd = 'terraform destroy -auto-approve -no-color -input=false'
      opts = { dir: tmpdir }
      allow(tf).to receive(:execute).with(cmd, opts).and_return(['ok', '', 0])
      allow(tf).to receive(:remove_from_inventory).with('192.168.1.1').and_return(status: 'ok')
      result = tf.tear_down('node_name' => '192.168.1.1')
      expect(result[:status]).to eq('ok')
    end
  end

  describe '#init' do
    let(:params) do
      {
        'dir' => tmpdir,
        'inventory' => tmpdir,
      }
    end
    let(:tf) { terraform.new(params) }

    after(:each) do
      FileUtils.remove_entry(tmpdir) if File.exist?(tmpdir)
    end

    it 'initializes an empty directory' do
      result = tf.send(:init)
      expect(result[:status]).to eq('ok')
      expect(result[:stdout]).to match('Terraform initialized in an empty directory!')
    end

    it 'initializes a directory with tf scripts' do
      result = tf.send(:init)
      expect(result[:status]).to eq('ok')
    end
  end

  describe '#validate' do
    let(:params) do
      {
        'dir' => tmpdir,
        'inventory' => tmpdir,
      }
    end
    let(:tf) { terraform.new(params) }

    after(:each) do
      FileUtils.remove_entry(tmpdir) if File.exist?(tmpdir)
    end

    it 'executes terraform validate on dir' do
      cmd = 'terraform validate -no-color'
      opts = { dir: tmpdir }
      allow(tf).to receive(:execute).with(cmd, opts).and_return(['Success! The configuration is valid.', '', 0])

      result = tf.send(:validate)
      expect(result[:status]).to eq('ok')
      expect(result[:stdout]).to match('Success! The configuration is valid.')
    end

    it 'raises exception when terraform validate fails' do
      cmd = 'terraform validate -no-color'
      opts = { dir: tmpdir }
      allow(tf).to receive(:execute).with(cmd, opts).and_return(['I was doing something.', 'Bad thing!', 1])

      expect {
        tf.send(:validate)
      }.to raise_error('Bad thing!')
    end
  end

  describe '#apply' do
    let(:params) do
      {
        'dir' => tmpdir,
        'inventory' => tmpdir,
      }
    end
    let(:tf) { terraform.new(params) }

    after(:each) do
      FileUtils.remove_entry(tmpdir) if File.exist?(tmpdir)
    end

    it 'executes terraform apply on dir' do
      cmd = 'terraform apply -auto-approve -no-color -input=false'
      opts = { dir: tmpdir }
      allow(tf).to receive(:execute).with(cmd, opts).and_return(['Apply complete!', '', 0])

      result = tf.send(:apply)
      expect(result[:status]).to eq('ok')
      expect(result[:stdout]).to match('Apply complete!')
    end

    it 'raises exception when terraform apply fails' do
      cmd = 'terraform apply -auto-approve -no-color -input=false'
      opts = { dir: tmpdir }
      allow(tf).to receive(:execute).with(cmd, opts).and_return(['I was doing something.', 'Bad thing!', 1])

      expect {
        tf.send(:apply)
      }.to raise_error('Bad thing!')
    end
  end

  describe '#output' do
    let(:params) do
      {
        'dir' => tmpdir,
        'inventory' => tmpdir,
      }
    end
    let(:tf) { terraform.new(params) }

    after(:each) do
      FileUtils.remove_entry(tmpdir) if File.exist?(tmpdir)
    end

    it 'executes terraform output on dir' do
      output = {
        "node": {
          "sensitive": false,
          "type": [
            'map',
            'string',
          ],
          "value": {
            "node_name_01": '10.178.196.188',
          },
        },
      }
      cmd = 'terraform output -no-color -json'
      opts = { dir: tmpdir }
      allow(tf).to receive(:execute).with(cmd, opts).and_return([output.to_json, '', 0])

      result = tf.send(:output)
      expect(result[:status]).to eq('ok')
      expect(result[:stdout]).to match('"node"')
    end

    it 'raises exception when terraform destroy fails' do
      cmd = 'terraform output -no-color -json'
      opts = { dir: tmpdir }
      allow(tf).to receive(:execute).with(cmd, opts).and_return(['I was doing something.', 'Bad thing!', 1])

      expect {
        tf.send(:output)
      }.to raise_error('Bad thing!')
    end
  end

  describe '#destroy' do
    let(:params) do
      {
        'dir' => tmpdir,
        'inventory' => tmpdir,
      }
    end
    let(:tf) { terraform.new(params) }

    after(:each) do
      FileUtils.remove_entry(tmpdir) if File.exist?(tmpdir)
    end

    it 'executes terraform destroy on dir' do
      cmd = 'terraform destroy -auto-approve -no-color -input=false'
      opts = { dir: tmpdir }
      allow(tf).to receive(:execute).with(cmd, opts).and_return(['Destroy complete!', '', 0])

      result = tf.send(:destroy)
      expect(result[:status]).to eq('ok')
      expect(result[:stdout]).to match('Destroy complete!')
    end

    it 'raises exception when terraform destroy fails' do
      cmd = 'terraform destroy -auto-approve -no-color -input=false'
      opts = { dir: tmpdir }
      allow(tf).to receive(:execute).with(cmd, opts).and_return(['I was doing something.', 'Bad thing!', 1])

      expect {
        tf.send(:destroy)
      }.to raise_error('Bad thing!')
    end
  end

  describe '#append_to_inventory' do
    let(:params) do
      {
        'dir' => tmpdir,
        'inventory' => tmpdir,
        'vm_name' => 'litmus-test',
      }
    end
    let(:tf) { terraform.new(params) }

    after(:each) do
      FileUtils.remove_entry(tmpdir) if File.exist?(tmpdir)
    end

    it 'returns information about newly added node' do
      stdout = '{"node":{"sensitive":false,"type":["map","string"],"value":{"litmus-test":"10.178.196.188"}}}'
      opts = {
        output: {
          stdout: stdout,
        },
      }
      result = tf.send(:append_to_inventory, opts)
      expect(result[:status]).to eq('ok')
      expect(result[:node_name]).to eq('litmus-test')
      expect(result[:node]).to eq('10.178.196.188')
    end

    it 'appends a node to the ssh_nodes group' do
      inventory_hash = {
        'version' => 2,
        'groups' => [
          { 'name' => 'docker_nodes', 'targets' => [] },
          { 'name' => 'ssh_nodes', 'targets' => [] },
          { 'name' => 'winrm_nodes', 'targets' => [] },
        ],
      }
      group_name = 'ssh_nodes'
      node = {
        'uri' => '10.178.196.188',
        'config' => {
          'transport' => 'ssh',
          'ssh' => {
            'user' => ENV['USER'],
            'host' => '10.178.196.188',
            'private-key' => '~/.ssh/litmus_compute',
            'host-key-check' => false,
            'port' => 22,
            'run-as' => 'root',
          },
        },
        'facts' => {
          'provisioner' => 'terraform_gcp',
          'platform' => 'default',
          'id' => 'litmus-test',
          'terraform_env' => tmpdir,
        },
      }

      stdout = '{"node":{"sensitive":false,"type":["map","string"],"value":{"litmus-test":"10.178.196.188"}}}'
      opts = {
        output: {
          stdout: stdout,
        },
      }
      expect(tf).to receive(:add_node_to_group).with(inventory_hash, node, group_name)
      tf.send(:append_to_inventory, opts)
    end
  end

  describe '#remove_from_inventory' do
    let(:params) do
      {
        'dir' => tmpdir,
        'inventory' => tmpdir,
        'vm_name' => 'litmus-test',
      }
    end
    let(:tf) { terraform.new(params) }

    after(:each) do
      FileUtils.remove_entry(tmpdir) if File.exist?(tmpdir)
    end

    it 'removes node from inventory file' do
      node_uri = '10.178.196.188'
      inventory_hash = {
        'version' => 2,
        'groups' => [
          { 'name' => 'docker_nodes', 'targets' => [] },
          { 'name' => 'ssh_nodes',
            'targets' => [
              { 'uri' => '10.178.196.188',
                'config' => {
                  'transport' => 'ssh',
                  'ssh' => {
                    'user' => 'litmus',
                    'host' => '10.178.196.188',
                    'private-key' => '~/.ssh/litmus_compute',
                    'host-key-check' => false,
                    'port' => 22,
                    'run-as' => 'root',
                  },
                },
                'facts' => {
                  'provisioner' => 'terraform_gcp',
                  'platform' => 'default',
                  'id' => 'litmus-test',
                  'terraform_env' => tmpdir,
                } },
            ] },
          { 'name' => 'winrm_nodes', 'targets' => [] },
        ],
      }

      tf.inventory_hash = inventory_hash
      expect(tf).to receive(:remove_node).with(inventory_hash, node_uri)
      result = tf.send(:remove_from_inventory, node_uri)
      expect(result[:status]).to eq('ok')
    end
  end
end
