# frozen_string_literal: true

require 'sidekiq/instrument/mixin'
require 'active_support/core_ext/string/inflections'

module Sidekiq::Instrument
  class ClientMiddleware
    include Sidekiq::Instrument::MetricNames

    def call(worker_class, job, queue, _redis_pool)
      # worker_class is a const in sidekiq >= 6.x
      klass = Object.const_get(worker_class.to_s)
      class_instance = klass.new

      # Depending on the type of perform called, this method can be hit either
      # once or twice for the same Job ID.
      #
      # perform_async:
      #   - once when it is enqueued, with no job['at'] key
      # perform_in:
      #   - once when it is scheduled, with job['at'] key
      #   - once when it is enqueued, without job['at'] key
      if job['at'].present?
        Statter.statsd.increment(metric_name(class_instance, 'schedule'))
        Statter.dogstatsd&.increment('sidekiq.schedule', worker_dog_options(class_instance, job))
      else
        WorkerMetrics.trace_workers_increment_counter(klass.name.underscore)
        Statter.statsd.increment(metric_name(class_instance, 'enqueue'))
        Statter.dogstatsd&.increment('sidekiq.enqueue', worker_dog_options(class_instance, job))
      end

      Statter.dogstatsd&.flush(sync: true)
      yield
    end
  end
end
