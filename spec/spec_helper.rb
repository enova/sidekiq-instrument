$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'simplecov'
require 'pry'
require 'statsd/instrument'
require 'sidekiq/testing'
require 'datadog/statsd'
require 'mock_redis'
require 'redis'

# Configure mock Redis to avoid requiring a running Redis server in tests
$mock_redis = MockRedis.new

class Redis
  def self.new(*args)
    $mock_redis
  end
end

# Configure Sidekiq to use mock Redis
module Sidekiq
  def self.redis
    yield $mock_redis if block_given?
    $mock_redis
  end
  
  # Sidekiq 8.x removed the Sidekiq[:key] = value API
  # Stub it out for backward compatibility with older tests
  @config_hash = {}
  
  def self.[]=(key, value)
    @config_hash ||= {}
    @config_hash[key] = value
  end
  
  def self.[](key)
    @config_hash ||= {}
    @config_hash.fetch(key, 25) # Default max_retries is 25 in Sidekiq
  end
end

Sidekiq::Testing.inline!

require 'sidekiq/instrument'

RSpec.configure do |config|
  config.include StatsD::Instrument::Matchers
end

Sidekiq::Instrument::Statter.dogstatsd = Datadog::Statsd.new('localhost', 8125)

class MyWorker
  include Sidekiq::Worker

  def perform; end
end

class MyOtherWorker
  include Sidekiq::Worker

  def perform; end

  def statsd_metric_name(event)
    "my_other_worker.#{event}"
  end
end
