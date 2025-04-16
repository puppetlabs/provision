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
