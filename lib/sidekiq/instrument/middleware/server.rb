# frozen_string_literal: true

require 'sidekiq/instrument/mixin'
require 'active_support/core_ext/string/inflections'

module Sidekiq::Instrument
  class ServerMiddleware
    include Sidekiq::Instrument::MetricNames

    def call(worker, job, _queue, &block)
      dequeue_string = is_retry(job) ? 'dequeue.retry' : 'dequeue'
      Statter.dogstatsd&.increment(dequeue_string, worker_dog_options(worker))
      Statter.statsd.increment(metric_name(worker, dequeue_string))

      start_time = Time.now
      yield block
      execution_time_ms = (Time.now - start_time) * 1000
      Statter.statsd.measure(metric_name(worker, 'runtime'), execution_time_ms)
      Statter.dogstatsd&.timing('sidekiq.runtime', execution_time_ms, worker_dog_options(worker))
    rescue StandardError => e
      # if we have retries left, increment the enqueue.retry counter to indicate the job is going back on the queue
      if max_retries(worker) > current_retries(job)
        WorkerMetrics.trace_workers_increment_counter(worker.class.to_s.underscore)
        Statter.dogstatsd&.increment('sidekiq.enqueue.retry', worker_dog_options(worker))
      end

      Statter.statsd.increment(metric_name(worker, 'error'))
      Statter.dogstatsd&.increment('sidekiq.error', worker_dog_options(worker))
      raise e
    ensure
      WorkerMetrics.trace_workers_decrement_counter(worker.class.to_s.underscore)
      Statter.dogstatsd&.flush(sync: true)
    end

    private

    def current_retries(job)
      job["redis_throttler_params"]["retry_count"]
    end
  
    def is_retry(job)
      current_retries(job) > 0
    end
  end
end
