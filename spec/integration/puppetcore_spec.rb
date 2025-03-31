# frozen_string_literal: true

require 'spec_helper'
require 'bundler'

RSpec.describe 'Gemfile.lock verification' do
  let(:parser) { Bundler::LockfileParser.new(Bundler.read_file(Bundler.default_lockfile)) }
  let(:private_source) { 'https://rubygems-puppetcore.puppet.com/' }

  # Helper method to get source remotes for a specific gem
  def get_gem_source_remotes(gem_name)
    spec = parser.specs.find { |s| s.name == gem_name }
    return [] unless spec

    source = spec.source
    return [] unless source.is_a?(Bundler::Source::Rubygems)

    source.remotes.map(&:to_s)
  end

  context 'when the environment is configured with a valid PUPPET_FORGE_TOKEN' do
    it 'returns puppet from puppetcore' do
      remotes = get_gem_source_remotes('puppet')
      expect(remotes).to eq([private_source]),
                         "Expected puppet to come from puppetcore, got: #{remotes.join(', ')}"
    end

    it 'returns facter from puppetcore' do
      remotes = get_gem_source_remotes('facter')
      expect(remotes).to eq([private_source]),
                         "Expected facter to come from puppetcore, got: #{remotes.join(', ')}"
    end

    it 'has PUPPET_FORGE_TOKEN set' do
      expect(ENV.fetch('PUPPET_FORGE_TOKEN', nil)).not_to be_nil,
                                                          'Expected PUPPET_FORGE_TOKEN to be set'
    end
  end
end
