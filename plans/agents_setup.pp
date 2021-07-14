plan provision::agents_setup(
  Optional[String] $collection = 'puppet7'
) {
  # get pe_server ?
  $server = get_targets('*').filter |$n| { $n.vars['role'] == 'server' }

  # get agents ?
  $agents = get_targets('*').filter |$n| { $n.vars['role'] != 'server' }

  # install agents
  run_task('puppet_agent::install', $agents, { 'collection' => $collection })

  # set the server
  $server_fqdn = run_command('facter fqdn', $server).to_data[0]['value']['stdout']
  run_task('puppet_conf', $agents, action => 'set', section => 'main', setting => 'server', value => $server_fqdn)

  $agents.each |$node| {
    $puppetnode_facts = facts($node)
    $platform = $puppetnode_facts['platform']

    $os_name = $puppetnode_facts['provisioner'] ? {
      'docker' => split($puppetnode_facts['platform'], Regexp['[/:-]'])[1],
      'docker_exp' => split($puppetnode_facts['platform'], Regexp['[/:-]'])[1],
      default => split($puppetnode_facts['platform'], Regexp['[/:-]'])[0]
    }

    $os_family = $os_name ? {
      /(^redhat|rhel|centos|scientific|oraclelinux)/ => 'redhat',
      /(^debian|ubuntu)/ => 'debian',
      /(^win)/ => 'windows',
      default => 'unsupported'
    }

    if $os_family == 'unsupported' {
      fail_plan('Not supported platform!')
    }

    if $os_family == 'debian' {
      run_task('provision::fix_secure_path', $node, 'fix secure path')
    }

    if $os_family == 'windows' {
      catch_errors() || {
        run_command('sc start puppet', $node, '_catch_errors' => true)
      }
    } else {
      catch_errors() || {
        run_command('systemctl start puppet', $node, '_catch_errors' => true)
        run_command('systemctl enable puppet', $node, '_catch_errors' => true)
      }
    }
  }

  # request signature
  run_command('puppet agent -t', $agents, '_catch_errors' => true)

  # wait for all certificates
  ctrl::sleep(5)

  # sign all requests
  run_command('puppetserver ca sign --all', $server, '_catch_errors' => true)
}
