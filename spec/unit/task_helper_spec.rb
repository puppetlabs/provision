# frozen_string_literal: true

require 'task_helper'

describe 'Utility Functions' do
  context '.platform_is_windows?' do
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
end
