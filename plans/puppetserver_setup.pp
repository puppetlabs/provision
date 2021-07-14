plan provision::puppetserver_setup(
  Optional[String] $collection = 'puppet7'
) {
  # get server
  $server = get_targets('*').filter |$node| { $node.vars['role'] == 'server' }

  # get facts
  $puppetserver_facts = facts($server[0])
  $platform = $puppetserver_facts['platform']

  # install puppetserver and start on master
  run_task(
    'provision::install_puppetserver',
    $server,
    'install and configure server',
    { 'collection' => $collection, 'platform' => $platform }
  )

  $os_name = $puppetserver_facts['provisioner'] ? {
    'docker' => split($puppetserver_facts['platform'], Regexp['[/:-]'])[1],
    'docker_exp' => split($puppetserver_facts['platform'], Regexp['[/:-]'])[1],
    default => split($puppetserver_facts['platform'], Regexp['[/:-]'])[0]
  }

  $os_family = $os_name ? {
    /(^redhat|rhel|centos|scientific|oraclelinux)/ => 'redhat',
    /(^debian|ubuntu)/ => 'debian',
    default => 'unsupported'
  }

  if $os_family == 'unsupported' {
    fail_plan('Not supported platform!')
  }

  if $os_family == 'debian' {
    run_task('provision::fix_secure_path', $server, 'fix secure path')
  }

  $fqdn = run_command('facter fqdn', $server).to_data[0]['value']['stdout']
  run_task('puppet_conf', $server, action => 'set', section => 'main', setting => 'server', value => $fqdn)

  run_command('systemctl start puppetserver', $server, '_catch_errors' => true)
  run_command('systemctl enable puppetserver', $server, '_catch_errors' => true)
}
