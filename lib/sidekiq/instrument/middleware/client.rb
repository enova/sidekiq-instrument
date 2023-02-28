# frozen_string_literal: true

require 'sidekiq/instrument/mixin'
require 'pry'

module Sidekiq::Instrument
  class ClientMiddleware
    include Sidekiq::Instrument::MetricNames

    def call(worker_class, job, queue, redis_pool)
      # worker_class is a const in sidekiq >= 6.x
      klass = Object.const_get(worker_class.to_s)
      class_instance = klass.new
      Statter.statsd.increment(metric_name(class_instance, 'enqueue'))
      Statter.dogstatsd&.increment('sidekiq.enqueue', worker_dog_options(class_instance))
      WorkerMetrics.trace_workers_increment_counter(klass.name, redis_pool)
      result = yield
      Statter.dogstatsd&.flush(sync: true)
      result
    end
  end
end
