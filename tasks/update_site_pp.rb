#!/opt/puppetlabs/puppet/bin/ruby
# frozen_string_literal: true

require 'json'
require 'open3'
require 'puppet'

def update_file(manifest)
  path = '/etc/puppetlabs/code/environments/production/manifests'
  _stdout, stderr, status = Open3.capture3("mkdir -p #{path}")
  raise Puppet::Error, "stderr: ' %{stderr}')" % { stderr: stderr } if status != 0

  site_path = File.join(path, 'site.pp')
  File.open(site_path, 'w+') { |f| f.write(manifest) }
  'site.pp updated'
end

params = JSON.parse($stdin.read)
manifest = params['manifest']

begin
  result = update_file(manifest)
  puts result.to_json
  exit 0
rescue Puppet::Error => e
  puts({ status: 'failure', error: e.message }.to_json)
  exit 1
end
