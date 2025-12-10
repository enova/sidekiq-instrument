$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'simplecov'
require 'pry'
require 'statsd/instrument'
require 'sidekiq/testing'
require 'datadog/statsd'
require 'mock_redis'
require 'redis'

# Sidekiq version detection for compatibility
SIDEKIQ_VERSION = Gem::Version.new(Sidekiq::VERSION)
SIDEKIQ_7_OR_HIGHER = SIDEKIQ_VERSION >= Gem::Version.new('7.0.0')

# Configure mock Redis to avoid requiring a running Redis server in tests
$mock_redis = MockRedis.new

class Redis
  def self.new(*args)
    $mock_redis
  end
end

# Configure Sidekiq to use mock Redis with version-specific handling
module Sidekiq
  class << self
    def redis(&block)
      if block_given?
        if SIDEKIQ_7_OR_HIGHER
          # Sidekiq 7.x+ uses redis-client and expects different signatures
          # Try calling with multiple args for compatibility
          begin
            block.call($mock_redis, nil, nil)
          rescue ArgumentError
            # Fall back to single argument for simpler blocks
            block.call($mock_redis)
          end
        else
          # Sidekiq 4.x-6.x uses simpler block signatures
          block.call($mock_redis)
        end
      else
        $mock_redis
      end
    end
  end
  
  # Sidekiq 7.x+ removed the Sidekiq[:key] = value API
  # Stub it out for backward compatibility with tests
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

# Stub Sidekiq API classes to avoid Redis connection issues
# This works across all Sidekiq versions (4.2-8.x)
class Sidekiq::Stats
  def initialize
    # Stubbed - no Redis connection needed
  end
  
  def processed
    0
  end
  
  def workers_size
    0
  end
  
  def enqueued
    0
  end
  
  def failed
    0
  end
end

class Sidekiq::Workers
  def initialize
    # Stubbed
  end
  
  def count
    0
  end
  
  def each
    # No workers in test
  end
end

class Sidekiq::Queue
  def self.all
    []
  end
  
  def initialize(name = 'default')
    @name = name
  end
  
  attr_reader :name
  
  def size
    0
  end
  
  def latency
    0
  end
  
  def clear
    # Stubbed
  end
end

RSpec.configure do |config|
  config.include StatsD::Instrument::Matchers
  
  config.before(:suite) do
    puts "\n🔧 Testing with Sidekiq #{Sidekiq::VERSION} (Ruby #{RUBY_VERSION})"
  end
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
