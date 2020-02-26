# frozen_string_literal: true

require 'yaml'
require 'fileutils'
require 'open3'
require 'puppet_litmus'
require 'erb'

require_relative 'task_helper.rb'

# Provision
module Provision
end

# Provision::Terraform
module Provision::Terraform
end

#-------------------------------
# Terraform Base Implementation
#-------------------------------

# Terraform::Provision::Base
class Provision::Terraform::Base
  include PuppetLitmus
  include Provision::TaskHelper

  attr_accessor :inventory_hash

  def initialize(opts = {})
    load_inventory_configuration(opts)
    load_ssh_configuration(opts)
    load_template_configuration(opts)
    load_metadata_configuration(opts)
    load_template_configuration(opts)
    load_provider_configuration(opts)
  end

  # provisions a node and appends it to the inventory file
  def provision(opts = {})
    # define where the terraform files for the node should be located
    @dir = find_or_create_terraform_environment(opts)
    init(opts)
    validate(opts)
    apply(opts)
    append_to_inventory(output: output(opts))
  end

  # tear_down a node and removes it from the inventory file
  def tear_down(opts = {})
    node_name = opts['node_name']
    get_terraform_env(node_name)
    destroy(opts)
    remove_from_inventory(node_name)
  end

  private

  def get_terraform_env(node_name)
    @dir ||= facts_from_node(@inventory_hash, node_name)['terraform_env']
  end

  def load_provider_configuration(opts = {})
    @platform = opts['platform'] || 'default'
    @vm_name = opts['vm_name'] || "litmus-test-#{@created_by}-#{(rand * 100_000_000).to_i}"
  end

  def load_inventory_configuration(opts = {})
    @inventory_location = File.expand_path(opts['inventory'] || '.')
    @inventory_full_path = File.join(@inventory_location, 'inventory.yaml')
    @inventory_hash = load_inventory
    @dir = opts['dir'] if opts['dir']
  end

  def load_ssh_configuration(opts = {})
    @ssh_user = opts['ssh_user'] || ENV['USER']
    @ssh_private_key = opts['ssh_private_key'] || '~/.ssh/litmus_compute'
    @ssh_public_key = opts['ssh_public_key'] || '~/.ssh/litmus_compute.pub'
    @ssh_host_key_check = opts['ssh_host_key_check'] || false
    @ssh_port = opts['ssh_port'] || 22
  end

  def load_metadata_configuration(opts = {})
    @created_by = opts['created_by'] || ENV['USER']
    @owner = opts['owner'] || ENV['USER']
    @build_url = opts['build_url'] || ''
  end

  def load_template_configuration(opts = {})
    @main_template = opts['main_template']
    @vars_template = opts['vars_template']
  end

  # init
  # execute terraform init on dir
  def init(_opts = {})
    cli_opts = ['-no-color']
    dir = File.expand_path(@dir) if @dir
    cli_opts = cli_opts.join(' ')

    if @dir ? Dir.exist?("#{dir}/.terraform") : Dir.exist?(File.expand_path('.terraform'))
      return { status: 'ok', stdout: 'Terraform has already been initialized' }
    end

    stdout_str, stderr_str, status = execute("terraform init #{cli_opts}", dir: dir)

    raise stderr_str unless status_is_success?(status)

    { status: 'ok', stdout: stdout_str }
  end

  # validate
  # executes terraform validate on dir
  def validate(_opts = {})
    dir = File.expand_path(@dir) if @dir
    stdout_str, stderr_str, status = execute('terraform validate -no-color', dir: dir)
    raise stderr_str unless status_is_success?(status)
    { status: 'ok', stdout: stdout_str }
  end

  # apply
  # executes terraform apply on dir
  def apply(opts = {})
    dir = File.expand_path(@dir) if @dir
    cli_opts = transcribe_to_cli(opts, dir)
    stdout_str, stderr_str, status = execute("terraform apply #{cli_opts}", dir: dir)
    raise stderr_str unless status_is_success?(status)
    { status: 'ok', stdout: stdout_str }
  end

  # output
  # reads the output from the state file
  def output(_opts = {})
    dir = File.expand_path(@dir) if @dir
    stdout_str, stderr_str, status = execute('terraform output -no-color -json', dir: dir)
    raise stderr_str unless status_is_success?(status)
    { status: 'ok', stdout: stdout_str }
  end

  # destroy
  # executes terraform destroy on dir
  def destroy(opts = {})
    dir = File.expand_path(@dir) if @dir
    cli_opts = transcribe_to_cli(opts, dir)
    stdout_str, stderr_str, status = execute("terraform destroy #{cli_opts}", dir: dir)
    raise stderr_str unless status_is_success?(status)
    { status: 'ok', stdout: stdout_str }
  end

  def load_inventory
    if !File.exist?(@inventory_full_path)
      get_inventory_hash(@inventory_full_path)
    else
      inventory_hash_from_inventory_file(@inventory_full_path)
    end
  end

  # append_to_inventory
  # parse the return value of terraform output
  # append node to invetory file
  # {
  #   "node": {
  #     "sensitive": false,
  #     "type": [
  #       "map",
  #       "string"
  #     ],
  #     "value": {
  #       "node01": "10.178.195.223",
  #     }
  #   }
  # }
  def append_to_inventory(opts = {})
    output = JSON.parse(opts[:output][:stdout])
    nodes = output['node']['value']

    nodes.each do |_vm_name, ip_address|
      node = {
        'uri' => ip_address,
        'config' => {
          'transport' => 'ssh',
          'ssh' => {
            'user' => @ssh_user,
            'host' => ip_address,
            'private-key' => @ssh_private_key,
            'host-key-check' => @ssh_host_key_check,
            'port' => @ssh_port,
            'run-as' => 'root',
          },
        },
        'facts' => {
          'provisioner' => 'terraform_gcp',
          'platform' => @platform,
          'id' => @vm_name,
          'terraform_env' => @dir,
        },
      }
      group_name = 'ssh_nodes'
      add_node_to_group(@inventory_hash, node, group_name)
      write_to_inventory_file(@inventory_hash, @inventory_full_path)
    end

    { status: 'ok', node_name: nodes.first[0], node: nodes.first[1] }
  end

  # removes a node from inventory file
  def remove_from_inventory(node_uri)
    @inventory_hash = remove_node(@inventory_hash, node_uri)
    write_to_inventory_file(@inventory_hash, @inventory_full_path)
    FileUtils.rm_r(@dir)
    STDERR.puts "Removed #{node_uri}"
    { status: 'ok' }
  end

  # The apply and destroy CLI opts map from the same task opts to cli opts, share that code.
  def transcribe_to_cli(opts, dir = nil)
    cli_opts = ['-auto-approve', '-no-color', '-input=false']
    cli_opts << "-state=#{File.expand_path(opts[:state], dir)}" if opts[:state]
    cli_opts << "-state-out=#{File.expand_path(opts[:state_out], dir)}" if opts[:state_out]

    if opts[:target]
      resources = opts[:target].is_a?(Array) ? opts[:target] : Array(opts[:target])
      resources.each { |resource| cli_opts << "-target=#{resource}" }
    end

    opts[:var]&.each { |k, v| cli_opts << "-var '#{k}=#{v}'" }

    if opts[:var_file]
      var_file_paths = opts[:var_file].is_a?(Array) ? opts[:var_file] : Array(opts[:var_file])
      var_file_paths.each { |path| cli_opts << "-var-file=#{File.expand_path(path, dir)}" }
    end

    cli_opts.join(' ')
  end

  # if the user has provided a directory that contains
  # their own terraform files we will just use that directory
  def find_or_create_terraform_environment(opts = {})
    return opts['dir'] if opts['dir']

    terraform_dirs = Dir.glob("#{File.join(@inventory_location, '.terraform')}/*/").map { |d| File.basename(d) }
    dir = File.expand_path(File.join(@inventory_location, '.terraform', get_terraform_dir(@platform.tr('/', '_'), terraform_dirs)))
    # return early if the directory has already exists
    return dir if File.exist?(dir)
    FileUtils.mkdir_p dir
    generate_terraform_files(dir)
    dir
  end

  # TODO: This method is not idempotent. I am not sure of the reason to make each provision
  # call generate a new environment. It almost sounds like the expectation is
  # that the user will never run provision on the same platform twice. Or that
  # each call to provision should assume that the user wants a new environemnt to be
  # created for them.
  # generate unique terraform directory name
  def get_terraform_dir(platform, terraform_dirs, i = 0)
    platform_dir = "#{platform}-#{i}"
    if terraform_dirs.include?(platform_dir)
      platform_dir = get_terraform_dir(platform, terraform_dirs, i + 1)
    end
    platform_dir
  end

  def generate_terraform_files(dir)
    render_main_tf(dir)
    render_vars_tf(dir)
  end

  def render_main_tf(dir)
    template = @main_template ? File.read(@main_template) : main_tf_template
    tf_file = File.join(dir, 'main.tf')
    render(template, tf_file)
  end

  def render_vars_tf(dir)
    template = @vars_template ? File.read(@vars_template) : vars_tf_template
    tf_file = File.join(dir, 'vars.tf')
    render(template, tf_file)
  end

  def render(template, file_path)
    File.open(file_path, 'w') do |f|
      f.write(ERB.new(template).result(binding))
    end
  end

  # Each cloud provider must implement this method
  def main_tf_template
    <<-TERRAFORM
    # main.tf
    TERRAFORM
  end

  # Each cloud provider must implement this method
  def vars_tf_template
    <<-TERRAFORM
    # vars.tf
    TERRAFORM
  end

  def status_is_success?(status)
    status.to_i.zero?
  end
end

#-----------------------------
# Google Cloud Provider - GCP
#-----------------------------

# Provision::Terraform::GCP
class Provision::Terraform::GCP < Provision::Terraform::Base
  def load_provider_configuration(opts = {})
    @credentials_file = opts['credentials_file'] || '~/.ssh/litmus-compute.json'
    @project_id = opts['project_id'] || 'litmus-compute'
    @platform = opts['platform'] || 'centos-cloud/centos-7'
    @region = opts['region'] || 'us-central1'
    @zone = opts['zone'] || 'us-central1-a'
    @machine_type = opts['machine_type'] || 'n1-standard-1'
    @vm_name = opts['vm_name'] || "litmus-test-#{@created_by}-#{(rand * 100_000_000).to_i}"
  end

  def main_tf_template
    template = <<-TERRAFORM
    # Based on the official docs provided by
    # https://cloud.google.com/community/tutorials/getting-started-on-gcp-with-terraform

    provider "google" {
      credentials = file(var.credentials_file)
      project     = var.project
      region      = var.region
    }

    resource "google_compute_instance" "node" {
      name         = var.vm_name
      machine_type = var.machine_type
      zone         = var.zone

      tags = ["litmus"]

      boot_disk {
        initialize_params {
          image = var.image
        }
      }

      network_interface {
        network = "default"
        access_config {
        }
      }

      metadata = {
        ssh-keys = "${var.ssh_user}:${file(var.ssh_public_key)}"
      }

      labels = {
        type = "litmus"
        created_by = var.created_by
        owner = var.owner
        build_url = var.build_url
      }
    }

    # return a map of
    # node name => public ip address
    output "node" {
      value =  "${
        map(
          google_compute_instance.node.name, google_compute_instance.node.network_interface.0.access_config.0.nat_ip
        )
      }"
    }
    TERRAFORM
    template
  end

  def vars_tf_template
    template = <<-TERRAFORM
    # Based on the official docs provided by
    # https://cloud.google.com/community/tutorials/getting-started-on-gcp-with-terraform

    variable "credentials_file" {
      type        = string
      description = "Path to gcp credentials file"
      default     = "#{@credentials_file}"
    }

    variable "ssh_user" {
      type = string
      description = "User used to connect via ssh"
      default     = "#{@ssh_user}"
    }

    variable "ssh_public_key" {
      type        = string
      description = "Path to ssh public key"
      default     = "#{@ssh_public_key}"
    }

    variable "project" {
      type        = string
      description = "Project ID"
      default     = "#{@project_id}"
    }

    variable "zone" {
      type = string
      description = "Compute Zone where to create the node"
      default     = "#{@zone}"
    }

    variable "region" {
      type = string
      description = "Compute Region where to create the node"
      default     = "#{@region}"
    }

    variable "image" {
      type        = string
      description = "The image from which to initialize this disk"
      default     = "#{@platform}"
    }

    variable "machine_type" {
      type        = string
      description = "Type of machine"
      default     = "#{@machine_type}"
    }

    variable "vm_name" {
      type        = string
      description = "The vm identifier"
      default     = "#{@vm_name}"
    }

    variable "created_by" {
      type        = string
      description = "name of the user that created the vm"
      default     = "#{@created_by}"
    }

    variable "owner" {
      type = string
      description = "Name of the Department/Team that owns this node (optional)"
      default = "#{@owner}"
    }

    variable "build_url" {
      type = string
      description = "URL of the CI job that created the vm (optional)"
      default = "#{@build_url}"
    }
  TERRAFORM
    template
  end
end
