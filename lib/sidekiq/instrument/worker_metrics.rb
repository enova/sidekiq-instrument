# frozen_string_literal: true

require 'redis'
require 'redis-client'
module Sidekiq
  module Instrument
    # Stores worker count
    class WorkerMetrics
      class_attribute :enabled, :namespace, :redis_config

      class_attribute :redis_password

      class << self
        def redis_pool
          @redis_pool ||= begin
            redis_client_config = RedisClient.config(redis_config)
            @redis = redis_client_config.new_pool(
              timeout: 0.5, size: Integer(ENV.fetch('RAILS_MAX_THREADS', 5))
            )
          end
        end

        def reset_redis
          @redis = nil
        end

        def trace_workers_increment_counter(klass_name, sidekiq_redis_pool)
          return unless enabled?

          if redis_config?
            redis_pool.with do |redis|
              redis.call 'HINCRBY', worker_metric_name, klass_name, 1
            end
          else
            sidekiq_redis_pool.with do |redis|
              redis.hincrby worker_metric_name, klass_name, 1
            end
          end
        end

        def trace_workers_decrement_counter(klass_name)
          return unless enabled?

          if redis_config?
            redis_pool.with do |redis|
              redis.call 'HINCRBY', worker_metric_name, klass_name, -1
            end
          else
            Sidekiq.redis do |redis|
              redis.hincrby worker_metric_name, klass_name, -1
            end
          end
        end

        def reset_counters
          return unless enabled?

          if redis_config?
            redis_pool.with do |redis|
              all_keys = redis.call 'HGETALL', worker_metric_name.all_keys
              redis.call 'HDEL', worker_metric_name, all_keys
            end
          else
            Sidekiq.redis do |redis|
              all_keys = redis.hgetall worker_metric_name.all_keys
              redis.hdel worker_metric_name, all_keys
            end
          end
        end

        def reset_counter(key)
          return unless enabled?

          if redis_config?
            redis_pool.with do |redis|
              redis.call 'HDEL', worker_metric_name, key
            end
          else
            Sidekiq.redis do |redis|
              redis.hdel worker_metric_name, key
            end
          end
        end

        def workers_in_queue
          return unless enabled?

          if redis_config?
            redis_pool.with do |redis|
              redis.call 'HGETALL', worker_metric_name
            end
          else
            Sidekiq.redis do |redis|
              redis.hgetall worker_metric_name
            end
          end
        end

        def worker_metric_name
          "sidekiq_instrument_trace_workers:#{namespace}:in_queue"
        end
      end
    end
  end
end
