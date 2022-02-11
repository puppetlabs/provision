source ENV['GEM_SOURCE'] || 'https://rubygems.org'

gem 'bolt'
gem 'puppet_litmus'
ruby_version_segments = Gem::Version.new(RUBY_VERSION.dup).segments
minor_version = ruby_version_segments[0..1].join('.')
group :development do
  gem "puppet-module-posix-default-r#{minor_version}", require: false, platforms: [:ruby]
  gem "puppet-module-posix-dev-r#{minor_version}",     require: false, platforms: [:ruby]
  gem "puppet-module-win-default-r#{minor_version}",   require: false, platforms: %i[mswin mingw x64_mingw]
  gem "puppet-module-win-dev-r#{minor_version}",       require: false, platforms: %i[mswin mingw x64_mingw]
  gem 'github_changelog_generator',                    require: false if Gem::Version.new(RUBY_VERSION.dup) >= Gem::Version.new('2.5.0')
  gem 'io-event', '0.4.0' # later versions require Ruby 3
  gem 'webmock'
end

# Evaluate Gemfile.local and ~/.gemfile if they exist
extra_gemfiles = [
  "#{__FILE__}.local",
  File.join(Dir.home, '.gemfile'),
]

extra_gemfiles.each do |gemfile|
  if File.file?(gemfile) && File.readable?(gemfile)
    eval(File.read(gemfile), binding)
  end
end
