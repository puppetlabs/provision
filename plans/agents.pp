plan provision::agents(
) {
  # get pe_server ?
  $server = get_targets('*').filter |$n| { $n.vars['role'] == 'pe' }
  # get agents ?
  $agents = get_targets('*').filter |$n| { $n.vars['role'] != 'pe' }
  $windows_agents = get_targets('*').filter |$n| { $n.vars['role'] == 'agent_windows' }

  # install agents
  run_task('puppet_agent::install', $agents)
  # set the server 
  $server_string = $server[0].name
  run_task('puppet_conf', $agents, action => 'set', section => 'main', setting => 'server', value => $server_string)
  run_command("powershell.exe -NoProfile -Nologo -Command 'Remove-Item -Path /ProgramData/PuppetLabs/puppet/etc/ssl -Force -Recurse'", $windows_agents, '_catch_errors' => true)
  # rm -rf /etc/puppetlabs/puppet/ssl
  # run agent -t
  run_command('puppet agent -t', $agents, '_catch_errors' => true)
}
