# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'sidekiq/instrument/version'

Gem::Specification.new do |spec|
  spec.name          = 'sidekiq-instrument'
  spec.version       = Sidekiq::Instrument::VERSION
  spec.authors       = ['Loan Application Services']
  spec.email         = ['application_services@enova.com']

  spec.summary       = 'StatsD & DogStatsD Instrumentation for Sidekiq'
  spec.homepage      = 'https://github.com/enova/sidekiq-instrument'
  spec.license       = 'MIT'

  spec.required_ruby_version = '>= 2.7.8'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.require_paths = ['lib']

  spec.add_dependency 'sidekiq', '>= 4.2'
  spec.add_dependency 'statsd-instrument', '>= 2.0.4'
  spec.add_dependency 'dogstatsd-ruby', '>= 5.5'
  spec.add_dependency 'activesupport', '>= 5.1'
  # Note: redis and redis-client are pulled in by sidekiq, no need to specify here
  # Sidekiq 4-6 uses redis ~> 3.2 or ~> 4.0
  # Sidekiq 7+ uses redis >= 4.2 + redis-client >= 0.9

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'pry-byebug'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'simplecov-cobertura'
  spec.add_development_dependency 'mock_redis'
end
