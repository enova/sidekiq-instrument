$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'sidekiq/instrument'

require 'statsd/instrument'

RSpec.configure do |config|
  config.include StatsD::Instrument::Matchers
end
