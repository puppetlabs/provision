#!/opt/puppetlabs/puppet/bin/ruby
require 'json'

def do_it(platform)
    puts "Using VMPooler for #{platform}"
    vmpooler = Net::HTTP.start(ENV['VMPOOLER_HOST'] || 'vmpooler.delivery.puppetlabs.net')

    reply = vmpooler.post("/api/v1/vm/#{platform}", '')
    raise "Error: #{reply}: #{reply.message}" unless reply.is_a?(Net::HTTPSuccess)

    data = JSON.parse(reply.body)
    raise "VMPooler is not ok: #{data.inspect}" unless data['ok'] == true

    hostname = "#{data[platform]['hostname']}.#{data['domain']}"
    puts "reserved #{hostname} in vmpooler"
    inventory_hash = { 'groups' =>
  [{ 'name' => 'ssh_nodes',
     'groups' => [{ 'name' => 'default', 'nodes' => [hostname] }],
     'config' => { 'transport' => 'ssh', 'ssh' => { 'host-key-check' => false } } }] }
    # ammend inventory if exists otherwise create a file
    File.open('inventory.yaml', 'w') { |f| f.write inventory_hash.to_yaml }
end

params = JSON.parse(STDIN.read)
platform = params['platform']

begin
  result = JSON.parse(do_it(platform))
  puts result.to_json
  exit 0
rescue => e
  puts({ _error: { kind: 'facter_task/failure', msg: e.message } }.to_json)
  exit 1
end
