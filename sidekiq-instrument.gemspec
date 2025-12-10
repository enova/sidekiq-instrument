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
  spec.add_dependency 'redis', '>= 3.2'  # Required by our code (worker_metrics.rb)
  spec.add_dependency 'statsd-instrument', '>= 2.0.4'
  spec.add_dependency 'dogstatsd-ruby', '>= 5.5'
  spec.add_dependency 'activesupport', '>= 5.1'
  # Note: redis-client is pulled in by Sidekiq 7+, no need to specify here

  # Note: bundler is not listed as a development dependency because it's
  # already provided by the Ruby environment. Different Ruby versions require
  # different bundler versions (2.x for Ruby 2.7, 3.x for Ruby 3.0-3.1, 4.x for Ruby 3.2+)
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'pry-byebug'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'simplecov-cobertura'
  spec.add_development_dependency 'mock_redis'
end
