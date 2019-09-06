plan provision::tester(
) {
  # get pe_server ?
  $server = get_targets('*').filter |$n| { $n.vars['role'] == 'pe' }
  $agents = get_targets('*').filter |$n| { $n.vars['role'] != 'pe' }
  $agent_names = $agents.map |$n| { $n.name }

  $manifest = "class { 'motd':\ncontent => 'foomph\n'\n}"
  $agent_names.each |$agent_name| {
    run_task('provision::update_node_pp', $server, manifest => $manifest, target_node => $agent_name)
  }
  run_command('puppet agent -t', $agents)
}
