# frozen_string_literal: true

require 'fileutils'

namespace :provision do
  # a collection of tasks used to help with the development of this module
  namespace :development do
    home = ENV['HOME']
    bolt_directory = File.join(home, '.puppetlabs', 'bolt')
    sitemodules_directory = File.join(home, '.puppetlabs', 'bolt', 'site-modules')
    current_directory = File.basename(Dir.getwd)

    desc 'Setup minimal development requirements'
    task :setup do
      puppet_modules = <<-PUPPETFILE
mod 'puppetlabs-puppet_agent'
mod 'puppetlabs-facts'
mod 'puppetlabs-puppet_conf'
    PUPPETFILE

      puppetfile = File.join(bolt_directory, 'Puppetfile')

      puts "[INFO] Check if #{bolt_directory} exists"
      FileUtils.mkdir_p(bolt_directory) unless File.exist?(bolt_directory)

      puts "[INFO] Check if #{sitemodules_directory} exists"
      FileUtils.mkdir_p(sitemodules_directory) unless File.exist?(sitemodules_directory)

      puts "[INFO] Check if minimal #{puppetfile} exists"
      File.write(puppetfile, puppet_modules) unless File.exist?(puppetfile)

      puts "[INFO] Ensure that modules are installed under #{bolt_directory}/modules"
      `bolt puppetfile install`

      Rake::Task['development:link'].invoke
    end

    desc "Link current module to #{sitemodules_directory}/"
    task :link do
      puts "[INFO] Link this module into #{bolt_directory}/site-modules"
      `ln -sf #{ENV['PWD']} #{bolt_directory}/site-modules/`
    end

    desc "Unlink current module from #{sitemodules_directory}/#{current_directory}"
    task :unlink do
      puts "[INFO] Unlink this module from #{bolt_directory}/site-modules/#{current_directory}"
      `unlink #{bolt_directory}/site-modules/#{current_directory}`
    end
  end
end
