# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
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

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.require_paths = ['lib']

  spec.add_dependency 'sidekiq', '>= 4.2', '< 7'
  spec.add_dependency 'statsd-instrument', '>= 2.0.4'
  spec.add_dependency 'dogstatsd-ruby', '~> 5.5.0'

  spec.add_development_dependency 'bundler', '~> 2.0', '>= 2.0.2'
  spec.add_development_dependency 'rake', '~> 12.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'pry-byebug', '~> 3.4'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'simplecov-cobertura'
end
