require 'yaml'
require 'puppet_litmus'

def get_inventory_hash(inventory_full_path)
  if File.file?(inventory_full_path)
    inventory_hash_from_inventory_file(inventory_full_path)
  else
    { 'groups' => [{ 'name' => 'docker_nodes', 'nodes' => [] }, { 'name' => 'ssh_nodes', 'nodes' => [] }, { 'name' => 'winrm_nodes', 'nodes' => [] }] }
  end
end

def run_local_command(command, wd = Dir.pwd)
  stdout, stderr, status = Open3.capture3(command, chdir: wd)
  error_message = "Attempted to run\ncommand:'#{command}'\nstdout:#{stdout}\nstderr:#{stderr}"
  raise error_message unless status.to_i.zero?
  stdout
end

def platform_uses_ssh(platform)
  uses_ssh = if platform !~ %r{win-}
               true
             else
               false
             end
  uses_ssh
end

def token_from_fogfile
  fog_file = File.join(Dir.home, '.fog')
  unless File.file?(fog_file)
    puts "Cannot file fog file at #{fog_file}"
    return nil
  end
  contents = YAML.load_file(fog_file)
  token = contents.dig(:default, :vmpooler_token)
  token
end
