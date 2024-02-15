# frozen_string_literal: true

require 'docker_helper'
require 'stringio'

describe 'Docker Helper Functions' do
  let(:container_id) { 'abc12345' }
  let(:inventory_location) { '.' }
  let(:full_inventory_location) { "#{inventory_location}/spec/fixtures/litmus_inventory.yaml" }
  let(:inventory_yaml) do
    <<-YAML
    version: 2
    groups:
    - name: docker_nodes
      targets:
      - name: #{container_id}
        uri: #{container_id}
        config:
          transport: docker
          docker:
            shell-command: bash -lc
            connect-timeout: 120
        facts:
          provisioner: docker_exp
          container_id: #{container_id}
          platform: litmusimage/debian:12
          os-release:
            PRETTY_NAME: Debian GNU/Linux 12 (bookworm)
            NAME: Debian GNU/Linux
            VERSION_ID: '12'
            VERSION: 12 (bookworm)
            VERSION_CODENAME: bookworm
            ID: debian
            HOME_URL: https://www.debian.org/
            SUPPORT_URL: https://www.debian.org/support
            BUG_REPORT_URL: https://bugs.debian.org/
    - name: ssh_nodes
      targets: []
    - name: winrm_nodes
      targets: []
    - name: lxd_nodes
      targets: []
    YAML
  end

  let(:os_release_facts) do
    <<-FILE
    PRETTY_NAME="Debian GNU/Linux 12 (bookworm)"
    NAME="Debian GNU/Linux"
    VERSION_ID="12"
    VERSION="12 (bookworm)"
    VERSION_CODENAME=bookworm
    ID=debian
    HOME_URL="https://www.debian.org/"
    SUPPORT_URL="https://www.debian.org/support"
    BUG_REPORT_URL="https://bugs.debian.org/"
    FILE
  end

  describe '.docker_exec' do
    it 'calls run_local_command' do
      allow(self).to receive(:run_local_command).with("docker exec #{container_id} a command").and_return('some output')
      expect(docker_exec(container_id, 'a command')).to eq('some output')
    end
  end

  describe '.docker_image_os_release_facts' do
    it 'returns parsed hash of /etc/os-release from container' do
      allow(self).to receive(:run_local_command)
        .with('docker run --rm litmusimage/debian:12 cat /etc/os-release')
        .and_return(os_release_facts)
      expect(docker_image_os_release_facts('litmusimage/debian:12')).to match(hash_including('PRETTY_NAME' => 'Debian GNU/Linux 12 (bookworm)'))
    end

    it 'returns minimal facts if parse fails for any reason' do
      allow(self).to receive(:run_local_command)
        .with('docker run --rm litmusimage/debian:12 cat /etc/os-release')
        .and_return(StandardError)
      expect(docker_image_os_release_facts('litmusimage/debian:12')).to match(hash_including('ID' => 'litmusimage_debian'))
    end
  end

  describe '.docker_tear_down' do
    it 'expect to raise error if inventory file is not found' do
      allow(File).to receive(:file?).and_return(false)
      expect { docker_tear_down(container_id, inventory_location) }.to raise_error(RuntimeError, "Unable to find '#{inventory_location}/spec/fixtures/litmus_inventory.yaml'")
    end

    it 'expect to return status ok' do
      allow(File).to receive(:file?).with(full_inventory_location).and_return(true)
      allow(File).to receive(:exist?).with(full_inventory_location).and_return(true)
      allow(File).to receive(:open).with(full_inventory_location, anything).and_yield(StringIO.new(inventory_yaml.dup))
      allow(self).to receive(:run_local_command).with("docker rm -f #{container_id}")
      allow(self).to receive(:remove_node).and_return(nil)
      expect {
        expect(docker_tear_down(container_id, inventory_location)).to eql({ status: 'ok' })
      }.to output("Removed #{container_id}\n").to_stdout
    end
  end

  describe '.docker_fix_missing_tty_error_message' do
    it 'execute command on container to disable mesg' do
      allow(self).to receive(:system).with("docker exec #{container_id} sed -i 's/^mesg n/tty -s \\&\\& mesg n/g' /root/.profile")
      expect(docker_fix_missing_tty_error_message(container_id)).to be_nil
    end
  end
end
