$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'simplecov'
require 'pry'
require 'statsd/instrument'
require 'sidekiq/testing'
require 'datadog/statsd'

# Check if real Redis is available (like in CI)
def redis_available?
  require 'redis'
  Redis.new(url: ENV['REDIS_URL'] || 'redis://localhost:6379/0', timeout: 1).ping == 'PONG'
rescue LoadError, NameError
  # redis gem not installed or Redis constant not defined
  false
rescue StandardError
  # Any connection errors (Redis::CannotConnectError, SocketError, Errno::ECONNREFUSED, etc.)
  false
end

USE_REAL_REDIS = ENV['USE_REAL_REDIS'] == 'true' || redis_available?

if USE_REAL_REDIS
  # Use real Redis connection (like CI does)
  require 'redis'
  
  Sidekiq.configure_client do |config|
    config.redis = { url: ENV['REDIS_URL'] || 'redis://localhost:6379/0' }
  end

  Sidekiq.configure_server do |config|
    config.redis = { url: ENV['REDIS_URL'] || 'redis://localhost:6379/0' }
  end
  
  # Sidekiq 7.x+ removed the Sidekiq[:key] = value API
  # Add compatibility shim for tests
  module Sidekiq
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
else
  # Fall back to mock_redis if no real Redis available
  require 'mock_redis'
  require 'redis'
  
  $mock_redis = MockRedis.new

  class Redis
    def self.new(*args)
      $mock_redis
    end
  end
  
  # Stub Sidekiq API classes when using mocks
  module Sidekiq
    class << self
      def redis(&block)
        if block_given?
          # Try different block signatures for compatibility
          begin
            block.call($mock_redis, nil, nil)
          rescue ArgumentError
            begin
              block.call($mock_redis, nil)
            rescue ArgumentError
              block.call($mock_redis)
            end
          end
        else
          $mock_redis
        end
      end
    end
    
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
  
  class Sidekiq::Stats
    def initialize
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
    end
    
    def count
      0
    end
    
    def each
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
    end
  end
end

Sidekiq::Testing.inline!

require 'sidekiq/instrument'

RSpec.configure do |config|
  config.include StatsD::Instrument::Matchers
  
  config.before(:suite) do
    redis_mode = USE_REAL_REDIS ? "REAL REDIS" : "MOCK REDIS"
    puts "\n🔧 Testing with Sidekiq #{Sidekiq::VERSION} (Ruby #{RUBY_VERSION}) - #{redis_mode}"
  end
  
  config.before(:each) do
    if USE_REAL_REDIS
      # Clear Redis before each test to ensure clean state
      Sidekiq.redis { |conn| conn.flushdb }
    end
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
