plan provision::tests_against_agents(
) {
  # get agents ?
  $agents = get_targets('*').filter |$n| { $n.vars['role'] != 'pe' }

  # iterate over agents
  $agents.each |$sut| {
    # pass the hostname as the sut, as the task is run locally.
    run_task('provision::run_tests', 'localhost', sut => $sut.name)
  }
}
