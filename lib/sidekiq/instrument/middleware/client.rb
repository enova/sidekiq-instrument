# frozen_string_literal: true

require 'sidekiq/instrument/mixin'
require 'active_support/core_ext/string/inflections'
require 'ddtrace'

module Sidekiq::Instrument
  class ClientMiddleware
    include Sidekiq::Instrument::MetricNames

    def call(worker_class, job, _queue, redis_pool)
      span = Datadog::Tracing.trace('sidekiq.job.enqueue', service: 'sidekiq', resource: job['class'])
      begin
        # worker_class is a const in sidekiq >= 6.x
        klass = Object.const_get(worker_class.to_s)
        class_instance = klass.new
        Statter.statsd.increment(metric_name(class_instance, 'enqueue'))
        Statter.dogstatsd&.increment('sidekiq.enqueue', worker_dog_options(class_instance))
        WorkerMetrics.trace_workers_increment_counter(klass.name.underscore, redis_pool)
        result = yield
      rescue StandardError => e
        span.set_error(e)
      ensure
        span.finish
        Statter.dogstatsd&.flush(sync: true)
      end
      result
    end
  end
end
