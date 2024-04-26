# frozen_string_literal: true

require 'json'

def docker_exec(container_id, command)
  run_local_command("docker exec #{container_id} #{command}")
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
      next if line.nil? || line.empty?

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

def docker_tear_down(container_id)
  run_local_command("docker rm -f #{container_id}")
  puts "Removed #{container_id}"
  { status: 'ok' }
end

# Workaround for fixing the bash message in stderr when tty is missing
def docker_fix_missing_tty_error_message(container_id)
  system("docker exec #{container_id} sed -i 's/^mesg n/tty -s \\&\\& mesg n/g' /root/.profile")
end
