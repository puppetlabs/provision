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
  gem 'github_changelog_generator',                    require: false, git: 'https://github.com/skywinder/github-changelog-generator', ref: '20ee04ba1234e9e83eb2ffb5056e23d641c7a018' if Gem::Version.new(RUBY_VERSION.dup) >= Gem::Version.new('2.2.2')
end
