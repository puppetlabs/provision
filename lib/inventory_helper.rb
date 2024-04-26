# frozen_string_literal: true

require 'yaml'
require 'delegate'

# simple bolt inventory manipulator
class InventoryHelper < SimpleDelegator
  def initialize(location)
    @location = location
    super(refresh)
  end

  # Load inventory from location in YAML format
  # or generate a default structure
  #
  # @return [Hash]
  def refresh
    x = YAML.load_file(@location) if File.file?(@location)
    { 'version' => 2, 'groups' => [] }.merge(x || {})
  end

  # Save inventory to location in yaml format
  def save
    File.open(@location, 'wb+') { |f| f.write(to_yaml) }
  end

  # Adds a node to a group specified, if group_name exists in inventory hash.
  #
  # @param node [Hash] node to add to the group
  # @param group [String] group of nodes to limit the search for the node_name in
  # @return [Hash] inventory_hash with node added to group if group_name exists in inventory hash.
  def add(node, group)
    # check if group exists
    if self['groups'].any? { |g| g['name'] == group }
      self['groups'].each do |g|
        g['targets'].push(node) if g['name'] == group
      end
    else
      # add new group
      self['groups'].push({ 'name' => group, 'targets' => [node] })
    end

    self
  end

  # Lookup a node
  #
  # @param uri [String] uri of node to find
  # @param name [String] name of node to find
  # @param group [String] limit search to group
  # @return [Hash] inventory target
  def lookup(uri = nil, name: nil, group: nil)
    value = uri || name
    key = uri.nil? ? 'name' : 'uri'

    self['groups'].each do |g|
      next unless (group && group == g['name']) || group.nil?
      g['targets'].each do |t|
        return t if t[key].eql? value
      end
    end

    # fallback lookup uri by name
    return lookup(value, group: group) if uri.nil?

    raise "Failed to lookup target for #{key} #{value} in inventory #{inspect}"
  end

  # Remove node
  #
  # @param node [Hash]
  # @return [Hash] inventory_hash with node of node_name removed.
  def remove(node)
    self['groups'].map! do |g|
      g['targets'].reject! { |target| target == node }
      g
    end

    self
  end

  class << self
    attr_accessor :instances

    def open(location = nil)
      # Inventory location is an optional task parameter.
      location = location.nil? ? Dir.pwd : location
      location = if File.directory?(location)
                   # DEPRECATED: puppet_litmus <= 1.3.0 support
                   if Gem.loaded_specs['puppet_litmus'] && Gem.loaded_specs['puppet_litmus'].version <= Gem::Version.new('1.3.0')
                     File.join(location, 'spec', 'fixtures', 'litmus_inventory.yaml')
                   else
                     File.join(location, 'inventory.yaml')
                   end
                 else
                   location
                 end

      @instances ||= {}
      @instances[location] = new(location) unless @instances.key? location
      @instances[location]
    end
  end

  protected

  attr_accessor :location
end
