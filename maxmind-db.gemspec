# frozen_string_literal: true

Gem::Specification.new do |s|
  s.authors     = ['William Storey']
  s.files       = Dir['**/*']
  s.name        = 'maxmind-db'
  s.summary     = 'A gem for reading MaxMind DB files.'
  s.version     = '1.0.0'

  s.description = 'A gem for reading MaxMind DB files. MaxMind DB is a binary file format that stores data indexed by IP address subnets (IPv4 or IPv6).'
  s.email       = 'wstorey@maxmind.com'
  s.homepage    = 'https://github.com/maxmind/MaxMind-DB-Reader-ruby'
  s.licenses    = ['Apache-2.0', 'MIT']
  s.metadata = {
    'bug_tracker_uri' => 'https://github.com/maxmind/MaxMind-DB-Reader-ruby/issues',
    'changelog_uri' => 'https://github.com/maxmind/MaxMind-DB-Reader-ruby/blob/master/CHANGELOG.md',
    'documentation_uri' => 'https://github.com/maxmind/MaxMind-DB-Reader-ruby',
    'homepage_uri' => 'https://github.com/maxmind/MaxMind-DB-Reader-ruby',
    'source_code_uri' => 'https://github.com/maxmind/MaxMind-DB-Reader-ruby',
  }
end
