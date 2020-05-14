def sanitise_inventory_location(location)
  # Inventory location is an optional task parameter. If not specified use the current directory
  location.nil? ? Dir.pwd : location
end

def get_inventory_hash(inventory_full_path)
  if File.file?(inventory_full_path)
    require 'puppet_litmus/inventory_manipulation'
    PuppetLitmus::InventoryManipulation.inventory_hash_from_inventory_file(inventory_full_path)
  else
    { 'version' => 2, 'groups' => [{ 'name' => 'docker_nodes', 'targets' => [] }, { 'name' => 'ssh_nodes', 'targets' => [] }, { 'name' => 'winrm_nodes', 'targets' => [] }] }
  end
end

def run_local_command(command, wd = Dir.pwd)
  require 'open3'
  stdout, stderr, status = Open3.capture3(command, chdir: wd)
  error_message = "Attempted to run\ncommand:'#{command}'\nstdout:#{stdout}\nstderr:#{stderr}"
  raise error_message unless status.to_i.zero?
  stdout
end

def platform_is_windows?(platform)
  # TODO: This seems sub-optimal. We should be able to override/specify what the real platform is on a per target basis
  # (plain_windows)            somewinorg/blah-windows-2019
  # (plain_windows)            myorg/some_image:windows-server
  # (bare_win_with_demlimiter) myorg/some_image:win-server-2008
  # (bare_win_with_demlimiter) myorg/win-2k8r2
  # No Match                   myorg/winderping    <--- Is this a Windows platform?
  # (plain_windows)            myorg/windows-server
  # (plain_windows)            windows-server
  # (bare_win_with_demlimiter) win-2008
  # (plain_windows)            webserserver-windows-2008
  # (bare_win_with_demlimiter) webserver-win-2008
  windows_regex = %r{(?<plain_windows>windows)|(?<bare_win_with_demlimiter>(?:^|[\/:\-\\;])win(?:[\/:\-\\;]|$))}i
  platform =~ windows_regex
end

def on_windows?
  # Stolen directly from Puppet::Util::Platform.windows?
  # Ruby only sets File::ALT_SEPARATOR on Windows and the Ruby standard
  # library uses that to test what platform it's on. In some places we
  # would use Puppet.features.microsoft_windows?, but this method can be
  # used to determine the behavior of the underlying system without
  # requiring features to be initialized and without side effect.
  !!File::ALT_SEPARATOR # rubocop:disable Style/DoubleNegation
end

def platform_uses_ssh(platform)
  # TODO: This seems sub-optimal. We should be able to override/specify what transport to use on a per target basis
  !platform_is_windows?(platform)
end

def token_from_fogfile(provider = "vmpooler")
  fog_file = File.join(Dir.home, '.fog')
  unless File.file?(fog_file)
    puts "Cannot file fog file at #{fog_file}"
    return nil
  end
  require 'yaml'
  contents = YAML.load_file(fog_file)
  token = nil
  if provider == "abs"
    token = contents.dig(:default, :abs_token)
  else
    token = contents.dig(:default, :vmpooler_token)
  end
  raise "Error: could not obtain #{provider} token from .fog file" if token.nil?
  token
rescue
  puts 'Failed to get vmpooler token from .fog file'
end

# Workaround for fixing the bash message in stderr when tty is missing
def fix_missing_tty_error_message(container_id)
  system("docker exec #{container_id} sed -i 's/^mesg n/tty -s \\&\\& mesg n/g' /root/.profile")
end
