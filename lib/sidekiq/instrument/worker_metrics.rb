# frozen_string_literal: true

require 'redis'
require 'redis-client'
module Sidekiq
  module Instrument
    # Stores worker count with a key sidekiq_instrument_trace_workers:#{namespace}:in_queue
    # Values are hash having keys as worker names.
    class WorkerMetrics
      class_attribute :enabled, :namespace

      class << self
        def trace_workers_increment_counter(klass_name)
          return unless enabled?

          Sidekiq.redis do |redis|
            redis.hincrby(worker_metric_name, klass_name, 1)
          end
        end

        def trace_workers_decrement_counter(klass_name)
          return unless enabled?

          Sidekiq.redis do |redis|
            redis.hincrby(worker_metric_name, klass_name, -1)
          end
        end

        def reset_counters
          return unless enabled?

          Sidekiq.redis do |redis|
            all_keys = redis.hgetall(worker_metric_name)
            redis.hdel(worker_metric_name, all_keys.keys)
          end
        end

        def reset_counter(key)
          return unless enabled?

          Sidekiq.redis do |redis|
            redis.hdel(worker_metric_name, key)
          end
        end

        def workers_in_queue
          return unless enabled?
          Sidekiq.redis do |redis|
            redis.hgetall(worker_metric_name)
          end
        end

        def worker_metric_name
          "sidekiq_instrument_trace_workers:#{namespace}:in_queue"
        end
      end
    end
  end
end
