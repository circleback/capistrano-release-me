
Gem::Specification.new do |s|
  s.name        = 'capistrano-releaseme'
  s.license     = 'LICENSE.txt'
  s.version     = '0.0.1'
  s.date        = '2015-05-06'
  s.summary     = 'help coordinate and track releases with cap deployment'
  s.description = <<-EOS

  EOS
  s.authors     = ['Jay Danielian']
  s.email       = ['info@circleback.com']
  s.files       = `git ls-files lib`.split(/\n/) + %w{ README.md LICENSE.txt }
  s.homepage    = 'http://github.com/circleback/capistrano-release-me'
  s.add_dependency 'capistrano', '~> 3.2.1'
  s.add_dependency 'git', '~> 1.2.9.1'
  s.add_dependency 'jira-ruby', '~> 0.1.14'
  s.add_dependency 'git-version-bump', '~> 0.14.0'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'rspec', '~> 3.0.0'
  s.require_path = 'lib'
end