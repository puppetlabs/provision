#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'uri'
require 'yaml'
require_relative '../lib/task_helper'
require_relative '../lib/docker_helper'
require_relative '../lib/inventory_helper'

def install_ssh_components(distro, version, container)
  case distro
  when %r{debian}, %r{ubuntu}, %r{cumulus}
    warn '!!! Disabling ESM security updates for ubuntu - no access without privilege !!!'
    docker_exec(container, 'rm -f /etc/apt/sources.list.d/ubuntu-esm-infra-trusty.list')
    docker_exec(container, 'apt-get update')
    docker_exec(container, 'apt-get install -y openssh-server openssh-client')
  when %r{centos}, %r{^el-}, %r{eos}, %r{oracle}, %r{ol}, %r{rhel|redhat}, %r{scientific}, %r{amzn}, %r{rocky}, %r{almalinux}, %r{fedora}
    if version == '6'
      # sometimes the redhat 6 variant containers like to eat their rpmdb, leading to
      # issues with "rpmdb: unable to join the environment" errors
      # This "fix" is from https://www.srv24x7.com/criticalyum-main-error-rpmdb-open-failed/
      docker_exec(container, 'bash -exc "rm -f /var/lib/rpm/__db*; ' \
                        'db_verify /var/lib/rpm/Packages; ' \
                        'rpm --rebuilddb; ' \
                        'yum clean all"')
    else
      # If systemd is running for init, ensure systemd has finished starting up before proceeding:
      check_init_cmd = 'if [[ "$(readlink /proc/1/exe)" == "/usr/lib/systemd/systemd" ]]; then ' \
                       'count=0 ; while ! [[ "$(systemctl is-system-running)" =~ ^running|degraded$ && $count > 20 ]]; ' \
                       'do sleep 0.1 ; count=$((count+1)) ; done ; fi'
      docker_exec(container, "bash -c '#{check_init_cmd}'")
    end
    packager = (version.to_i > 8) ? 'dnf' : 'yum'
    docker_exec(container, "#{packager} install -y sudo openssh-server openssh-clients")
    ssh_folder = docker_exec(container, 'ls /etc/ssh/')
    docker_exec(container, 'ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key -N ""') unless ssh_folder.include?('ssh_host_rsa_key')
    docker_exec(container, 'ssh-keygen -t dsa -f /etc/ssh/ssh_host_dsa_key -N ""') unless ssh_folder.include?('ssh_host_dsa_key')
  when %r{opensuse}, %r{sles}
    docker_exec(container, 'zypper -n in openssh')
    docker_exec(container, 'ssh-keygen -A')
    docker_exec(container, 'sed -ri "s/^#?UsePAM .*/UsePAM no/" /etc/ssh/sshd_config')
  else
    raise "distribution #{distro} not yet supported on docker"
  end

  # Make sshd directory, set root password
  docker_exec(container, 'mkdir -p /var/run/sshd')
  docker_exec(container, 'bash -c "echo root:root | /usr/sbin/chpasswd"')

  # fix ssh
  docker_exec(container, 'sed -ri "s/^#?PermitRootLogin .*/PermitRootLogin yes/" /etc/ssh/sshd_config')
  docker_exec(container, 'sed -ri "s/^#?PasswordAuthentication .*/PasswordAuthentication yes/" /etc/ssh/sshd_config')
  docker_exec(container, 'sed -ri "s/^#?UseDNS .*/UseDNS no/" /etc/ssh/sshd_config')
  docker_exec(container, 'sed -e "/HostKey.*ssh_host_e.*_key/ s/^#*/#/" -ri /etc/ssh/sshd_config')
  # Current RedHat/CentOs 7 packs an old version of pam, which are missing a
  # crucial patch when running unprivileged containers.  See:
  # https://bugzilla.redhat.com/show_bug.cgi?id=1728777
  docker_exec(container, 'sed "s@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g" -i /etc/pam.d/sshd') \
    if distro =~ %r{rhel|redhat|centos} && version =~ %r{^7}

  # install ssh
  case distro
  when %r{debian}, %r{ubuntu}
    docker_exec(container, 'service ssh restart')
  when %r{centos}, %r{^el-}, %r{eos}, %r{fedora}, %r{ol}, %r{rhel|redhat}, %r{scientific}, %r{amzn}, %r{rocky}, %r{almalinux}
    if %r{^(7|8|9|2)}.match?(version)
      docker_exec(container, '/usr/sbin/sshd')
    else
      docker_exec(container, 'service sshd restart')
    end
  when %r{opensuse}, %r{sles}
    docker_exec(container, '/usr/sbin/sshd')
  else
    raise "distribution #{distro} not yet supported on docker"
  end
end

# We check for a local port open by binding a raw socket to it
# If the socket can successfully bind, then the port is open
def local_port_open?(port)
  require 'socket'
  require 'timeout'
  Timeout.timeout(1) do
    socket = Socket.new(Socket::Constants::AF_INET,
                        Socket::Constants::SOCK_STREAM,
                        0)
    socket.bind(Socket.pack_sockaddr_in(port, '0.0.0.0'))
    true
  rescue Errno::EADDRINUSE, Errno::ECONNREFUSED
    false
  ensure
    socket.close
  end
rescue Timeout::Error
  false
end

# These defaults are arbitrary but outside the well-known range
def random_ssh_forwarding_port(start_port = 52_222, end_port = 52_999)
  raise 'start_port must be less than end_port' if start_port >= end_port

  # This stops us from potentially allocating an invalid port
  raise 'Could not find an open port to use for SSH forwarding' if end_port > 65_535

  port = rand(start_port..end_port)
  return port if local_port_open?(port)

  # Try again but bump up the port ranges
  # Since we thrown an exception above if the end port is > 65535,
  # there is a hard limit to the amount of times we can retry depending
  # on the start port and the diff between the end port and the start port.
  port_diff = end_port - start_port
  new_start_port = start_port + port_diff + 1
  new_end_port = end_port + port_diff + 1
  random_ssh_forwarding_port(new_start_port, new_end_port)
end

def provision(docker_platform, inventory, vars)
  os_release_facts = docker_image_os_release_facts(docker_platform)
  distro = os_release_facts['ID']
  version = os_release_facts['VERSION_ID']

  # support for ssh to remote docker
  hostname = (ENV['DOCKER_HOST'].nil? || ENV['DOCKER_HOST'].empty?) ? 'localhost' : URI.parse(ENV.fetch('DOCKER_HOST', nil)).host || ENV.fetch('DOCKER_HOST', nil)
  begin
    # Use the current docker context to determine the docker hostname
    docker_context = JSON.parse(run_local_command('docker context inspect'))[0]
    docker_uri = URI.parse(docker_context['Endpoints']['docker']['Host'])
    hostname = docker_uri.host unless docker_uri.host.nil? || docker_uri.host.empty?
  rescue RuntimeError
    # old clients may not support docker context
  end

  warn '!!! Using private port forwarding!!!'
  front_facing_port = random_ssh_forwarding_port

  inventory_node = {
    'uri' => "#{hostname}:#{front_facing_port}",
    'alias' => "#{hostname}:#{front_facing_port}",
    'config' => {
      'transport' => 'ssh',
      'ssh' => {
        'user' => 'root',
        'password' => 'root',
        'port' => front_facing_port,
        'host-key-check' => false,
        'connect-timeout' => 120
      }
    },
    'facts' => {
      'provisioner' => 'docker',
      'platform' => docker_platform,
      'os-release' => os_release_facts
    }
  }

  docker_run_opts = ''
  unless vars.nil?
    var_hash = YAML.safe_load(vars)
    inventory_node['vars'] = var_hash
    docker_run_opts = var_hash['docker_run_opts'].flatten.join(' ') unless var_hash['docker_run_opts'].nil?
  end

  if docker_platform.match?(%r{debian|ubuntu})
    docker_run_opts += ' --volume /sys/fs/cgroup:/sys/fs/cgroup:rw' unless docker_run_opts.include?('--volume /sys/fs/cgroup:/sys/fs/cgroup')
    docker_run_opts += ' --cgroupns=host' unless docker_run_opts.include?('--cgroupns')
  end

  creation_command = 'docker run -d -it --privileged --tmpfs /tmp:exec '
  creation_command += "-p #{front_facing_port}:22 "
  creation_command += "#{docker_run_opts} " unless docker_run_opts.nil?
  creation_command += docker_platform

  container_id = run_local_command(creation_command).strip[0..11]

  install_ssh_components(distro, version, container_id)

  inventory_node['name'] = container_id
  inventory_node['facts']['container_id'] = container_id

  inventory.add(inventory_node, 'ssh_nodes').save

  { status: 'ok', node_name: inventory_node['name'], node: inventory_node }
end

params = JSON.parse($stdin.read)
platform = params['platform']
action = params['action']
node_name = params['node_name']
inventory = InventoryHelper.open(params['inventory'])
vars = params['vars']
raise 'specify a node_name when tearing down' if action == 'tear_down' && node_name.nil?
raise 'specify a platform when provisioning' if action == 'provision' && platform.nil?

unless node_name.nil? ^ platform.nil?
  case action
  when 'tear_down'
    raise 'specify only a node_name, not platform, when tearing down'
  when 'provision'
    raise 'specify only a platform, not node_name, when provisioning'
  else
    raise 'specify only one of: node_name, platform'
  end
end

begin
  result = provision(platform, inventory, vars) if action == 'provision'
  if action == 'tear_down'
    node = inventory.lookup(node_name, group: 'ssh_nodes')
    result = docker_tear_down(node['facts']['container_id'])
    inventory.remove(node).save
  end
  puts result.to_json
  exit 0
rescue StandardError => e
  puts({ _error: { kind: 'provision/docker_failure', msg: e.message, backtrace: e.backtrace } }.to_json)
  exit 1
end
