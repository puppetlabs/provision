require 'json'
require 'rspec'
require 'spec_helper'
require 'net/ssh'
require_relative '../../tasks/vagrant'

describe 'vagrant' do
  let(:provider) { 'virtualbox' }
  let(:platform) { 'generic/debian10' }

  include_context('with tmpdir')

  before(:each) do
    # Stub $stdin.read to return a predefined JSON string
    allow($stdin).to receive(:read).and_return({
      platform:,
      action: 'provision',
      vars: 'role: worker1',
      inventory: tmpdir,
      enable_synced_folder: 'true',
      provider:,
      hyperv_vswitch: 'hyperv_vswitch',
      hyperv_smb_username: 'hyperv_smb_username'
    }.to_json)
    allow(Open3).to receive(:capture3).with(%r{vagrant up --provider #{provider}}, any_args).and_return(['', '', 0]).once
    allow(File).to receive(:read).with(%r{#{tmpdir}.*\.vagrant}).and_return('some_unique_id')
    allow(Open3).to receive(:capture3).with(%r{vagrant ssh-config}, any_args).and_return(['', '', 0]).once
    allow(Net::SSH).to receive(:start).and_return(true)
  end

  it 'provisions a new vagrant box when action is provision' do
    expect { vagrant }.to raise_error(SystemExit).and output(
      include('"status":"ok"', '"platform":"generic/debian10"', '"role":"worker1"'),
    ).to_stdout
  end
end

describe '#vagrant_version' do
  it 'returns the parsed vagrant version' do
    allow(Open3).to receive(:capture3).with('vagrant --version', any_args).and_return(['Vagrant 2.3.4', '', 0])
    expect(vagrant_version).to eq(Gem::Version.new('2.3.4'))
  end

  it 'memoizes the result' do
    allow(Open3).to receive(:capture3).with('vagrant --version', any_args).and_return(['Vagrant 2.3.4', '', 0]).once
    vagrant_version
    vagrant_version
  end
end

describe '#supports_windows_platform?' do
  it 'returns true for vagrant >= 2.2.0' do
    allow(Open3).to receive(:capture3).with('vagrant --version', any_args).and_return(['Vagrant 2.3.0', '', 0])
    expect(supports_windows_platform?).to be true
  end
end

describe '#generate_vagrantfile' do
  include_context('with tmpdir')

  it 'includes a provider config block with cpus when specified' do
    path = File.join(tmpdir, 'Vagrantfile')
    generate_vagrantfile(path, 'ubuntu-20.04', false, nil, 2, nil, nil, nil, nil, nil)
    content = File.read(path)
    expect(content).to include('v.cpus = 2')
  end

  it 'includes box_url when specified, substituting the platform name' do
    path = File.join(tmpdir, 'Vagrantfile')
    generate_vagrantfile(path, 'ubuntu-20.04', false, 'virtualbox', nil, nil, nil, nil, nil, 'https://example.com/%BOX%.box')
    content = File.read(path)
    expect(content).to include("config.vm.box_url = 'https://example.com/ubuntu-20.04.box'")
  end
end

describe 'vagrant validation errors' do
  include_context('with tmpdir')

  it 'raises when both node_name and platform given for provision' do
    allow($stdin).to receive(:read).and_return({ action: 'provision', platform: 'foo', node_name: 'bar', inventory: tmpdir }.to_json)
    expect { vagrant }.to raise_error(RuntimeError, /specify only a platform/)
  end

  it 'raises when both node_name and platform given for tear_down' do
    allow($stdin).to receive(:read).and_return({ action: 'tear_down', platform: 'foo', node_name: 'bar', inventory: tmpdir }.to_json)
    expect { vagrant }.to raise_error(RuntimeError, /specify only a node_name/)
  end

  it 'raises when both node_name and platform given for an unknown action' do
    allow($stdin).to receive(:read).and_return({ action: 'other', platform: 'foo', node_name: 'bar', inventory: tmpdir }.to_json)
    expect { vagrant }.to raise_error(RuntimeError, /specify only one of/)
  end
end

describe 'vagrant rescue' do
  include_context('with tmpdir')

  it 'exits 1 with an error JSON when provision raises' do
    allow($stdin).to receive(:read).and_return({ platform: 'generic/ubuntu20', action: 'provision', inventory: tmpdir }.to_json)
    allow(Open3).to receive(:capture3).with(%r{vagrant up}, any_args).and_return(['', 'vagrant failed!', 1])
    expect { vagrant }.to(
      raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
        .and(output(/vagrant_failure/).to_stdout),
    )
  end
end
