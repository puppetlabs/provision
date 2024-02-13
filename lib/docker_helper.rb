# frozen_string_literal: true

def docker_exec(container, command)
  run_local_command("docker exec #{container} #{command}")
end

def docker_image_os_release_facts(image)
  os_release_facts = {}
  begin
    os_release = run_local_command("docker run --rm #{image} cat /etc/os-release")
    # The or-release file is a newline-separated list of environment-like
    # shell-compatible variable assignments.
    re = '^(.+)=(.+)'
    os_release.each_line do |line|
      line = line.strip || line
      next if line.nil || line.empty?

      _, key, value = line.match(re).to_a
      # The values seems to be quoted most of the time, however debian only quotes
      # some of the values :/.  Parse it, as if it was a JSON string.
      value = JSON.parse(value) unless value[0] != '"'
      os_release_facts[key] = value
    end
  rescue StandardError
    # fall through to parsing the id and version from the image if it doesn't have `/etc/os-release`
    id, version_id = image.split(':')
    id = id.sub(%r{/}, '_')
    os_release_facts['ID'] = id
    os_release_facts['VERSION_ID'] = version_id
  end
  os_release_facts
end

def docker_tear_down(node_name, inventory_location)
  include PuppetLitmus::InventoryManipulation
  inventory_full_path = File.join(inventory_location, '/spec/fixtures/litmus_inventory.yaml')
  raise "Unable to find '#{inventory_full_path}'" unless File.file?(inventory_full_path)

  inventory_hash = inventory_hash_from_inventory_file(inventory_full_path)
  node_facts = facts_from_node(inventory_hash, node_name)
  remove_docker = "docker rm -f #{node_facts['container_id']}"
  run_local_command(remove_docker)
  remove_node(inventory_hash, node_name)
  puts "Removed #{node_name}"
  File.open(inventory_full_path, 'w') { |f| f.write inventory_hash.to_yaml }
  { status: 'ok' }
end
