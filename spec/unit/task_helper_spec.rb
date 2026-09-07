# frozen_string_literal: true

require 'task_helper'

describe 'Utility Functions' do
  describe '.platform_is_windows?' do
    it 'correctly identifies Windows platforms' do
      expect(platform_is_windows?('somewinorg/blah-windows-2019')).to be_truthy
      expect(platform_is_windows?('somewinorg/blah-WinDows-2019')).to be_truthy
      expect(platform_is_windows?('myorg/some_image:windows-server')).to be_truthy
      expect(platform_is_windows?('myorg/some_image:win-server-2008')).to be_truthy
      expect(platform_is_windows?('myorg/win-2k8r2')).to be_truthy
      expect(platform_is_windows?('myorg/windows-server')).to be_truthy
      expect(platform_is_windows?('windows-server')).to be_truthy
      expect(platform_is_windows?('win-2008')).to be_truthy
      expect(platform_is_windows?('webserserver-windows-2008')).to be_truthy
      expect(platform_is_windows?('webserver-win-2008')).to be_truthy
      expect(platform_is_windows?('myorg/winderping')).to be_falsey
      expect(platform_is_windows?('2012r2')).to be_falsey
      expect(platform_is_windows?('redhat8')).to be_falsey
    end
  end

  describe '.token_from_fogfile' do
    it 'returns nil and prints a warning when the fog file does not exist' do
      allow(File).to receive(:file?).and_return(false)
      result = nil
      expect { result = token_from_fogfile }.to output(%r{Cannot file fog file}).to_stdout
      expect(result).to be_nil
    end

    it 'prints a warning and returns nil when reading the fog file raises an error' do
      allow(File).to receive(:file?).and_return(true)
      allow(YAML).to receive(:load_file).and_raise(StandardError, 'bad file')
      expect { token_from_fogfile }.to output(%r{Failed to get token}).to_stdout
    end
  end
end
