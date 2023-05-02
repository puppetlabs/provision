plan provision::teardown(
) {
  $all_nodes = get_targets('*')
  $all_node_names = $all_nodes.map |$n| { $n.name }
  $all_node_names.each |$node_name| {
    run_task('provision::abs', 'localhost', action=> 'tear_down', node_name=> $node_name, inventory => './')
  }
}
