$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'simplecov'
require 'statsd/instrument'
require 'sidekiq/instrument'

RSpec.configure do |config|
  config.include StatsD::Instrument::Matchers
end
