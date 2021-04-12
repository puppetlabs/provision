plan provision::provisioner(
) {
  # bolt command run 'touch ./inventory.yaml'
  # provision server machine, set role 
  run_task('provision::abs', 'localhost', action => 'provision', platform => 'centos-7-x86_64', inventory => './', vars => 'role: pe')
  # provision agents  agent_linux agent_windows
  run_task('provision::abs', 'localhost', action => 'provision', platform => 'centos-6-x86_64', inventory => './', vars => 'role: agent_linux')
  run_task('provision::abs', 'localhost', action => 'provision', platform => 'win-2016-x86_64', inventory => './', vars => 'role: agent_windows')
}
