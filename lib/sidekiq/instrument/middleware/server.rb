# frozen_string_literal: true

require 'sidekiq/instrument/mixin'
require 'active_support/core_ext/string/inflections'
require 'ddtrace'

module Sidekiq::Instrument
  class ServerMiddleware
    include Sidekiq::Instrument::MetricNames

    def call(worker, job, _queue, &block)
      span = Datadog::Tracing.trace('sidekiq.job.dequeue', service: 'sidekiq', resource: job['class'])
      begin
        Statter.statsd.increment(metric_name(worker, 'dequeue'))
        Statter.dogstatsd&.increment('sidekiq.dequeue', worker_dog_options(worker))

        start_time = Time.now
        yield block
        execution_time_ms = (Time.now - start_time) * 1000
        Statter.statsd.measure(metric_name(worker, 'runtime'), execution_time_ms)
        Statter.dogstatsd&.timing('sidekiq.runtime', execution_time_ms, worker_dog_options(worker))
      rescue StandardError => e
        span.set_error(e)
        Statter.statsd.increment(metric_name(worker, 'error'))
        Statter.dogstatsd&.increment('sidekiq.error', worker_dog_options(worker))
        raise e
      ensure
        span.finish
        WorkerMetrics.trace_workers_decrement_counter(worker.class.to_s.underscore)
        Statter.dogstatsd&.flush(sync: true)
      end
    end
  end
end
