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

      # This is needed because the ClientMiddleware is called twice for scheduled jobs
      # - Once when it gets scheduled
      # - Once when it gets dequeued for processing
      # We only want to increment the enqueue metric when the job is scheduled and
      # Sidekiq::Context.current[:class] is only ever set when the job is scheduled
      if Sidekiq::Context.current[:class].present?
        WorkerMetrics.trace_workers_increment_counter(klass.name.underscore)
        Statter.statsd.increment(metric_name(class_instance, 'enqueue'))
        Statter.dogstatsd&.increment('sidekiq.enqueue', worker_dog_options(class_instance))
      end

      Statter.dogstatsd&.flush(sync: true)
      yield
    end
  end
end
