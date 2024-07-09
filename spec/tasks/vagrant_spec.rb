require 'json'
require 'rspec'
require 'spec_helper'
require 'net/ssh'

describe 'vagrant' do
  let(:provider) { 'virtualbox' }
  let(:platform) { 'generic/debian10' }

  before(:each) do
    # Stub $stdin.read to return a predefined JSON string
    allow($stdin).to receive(:read).and_return({
      platform: platform,
      action: 'provision',
      vars: 'role: worker1',
      inventory: Dir.pwd.to_s,
      enable_synced_folder: 'true',
      provider: provider,
      hyperv_vswitch: 'hyperv_vswitch',
      hyperv_smb_username: 'hyperv_smb_username'
    }.to_json)
    allow(Open3).to receive(:capture3).with(%r{vagrant up --provider #{provider}}, any_args).and_return(['', '', 0]).once
    allow(File).to receive(:read).with(%r{#{Dir.pwd}/spec/fixtures/.vagrant}).and_return('some_unique_id')
    allow(Open3).to receive(:capture3).with(%r{vagrant ssh-config}, any_args).and_return(['', '', 0]).once
    allow(Net::SSH).to receive(:start).and_return(true)
    require_relative '../../tasks/vagrant'
  end

  it 'provisions a new vagrant box when action is provision' do
    expect { vagrant }.to output(%r{"status":"ok"}).to_stdout
    expect { vagrant }.to output(%r{"platform":"generic/debian10"}).to_stdout
    expect { vagrant }.to output(%r{"role":"worker1"}).to_stdout
  end
end
