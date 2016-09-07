# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'sidekiq/instrument/version'

Gem::Specification.new do |spec|
  spec.name          = 'sidekiq-instrument'
  spec.version       = Sidekiq::Instrument::VERSION
  spec.authors       = ['Matt Larraz']
  spec.email         = ['mlarraz@enova.com']

  spec.summary       = 'StatsD instrumentation for Sidekiq'
  spec.homepage      = 'https://github.com/enova/sidekiq-instrument'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.require_paths = ['lib']

  spec.add_dependency 'sidekiq', '~> 4.0'
  spec.add_dependency 'statsd-instrument', '~> 2.0', '>= 2.0.4'

  spec.add_development_dependency 'bundler', '~> 1.12'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'pry-byebug', '~> 3.4'
  spec.add_development_dependency 'coveralls', '~> 0.8'
end
