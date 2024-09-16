# frozen_string_literal: true

require 'sidekiq/instrument/mixin'
require 'active_support/core_ext/string/inflections'

module Sidekiq::Instrument
  class ServerMiddleware
    include Sidekiq::Instrument::MetricNames

    def call(worker, job, _queue, &block)
      dequeue_string = is_retry(job) ? 'dequeue.retry' : 'dequeue'
      Statter.dogstatsd&.increment("sidekiq.#{dequeue_string}", worker_dog_options(worker, job))
      Statter.statsd.increment(metric_name(worker, dequeue_string))

      start_time = Time.now
      yield block
      execution_time_ms = (Time.now - start_time) * 1000
      Statter.dogstatsd&.timing('sidekiq.runtime', execution_time_ms, worker_dog_options(worker, job))
      Statter.statsd.measure(metric_name(worker, 'runtime'), execution_time_ms)
    rescue Exception => e
      dd_options = worker_dog_options(worker, job)
      dd_options[:tags] << "error:#{e.class.name}"

      # if we have retries left, increment the enqueue.retry counter to indicate the job is going back on the queue
      if max_retries(worker) > current_retries(job) + 1
        WorkerMetrics.trace_workers_increment_counter(worker.class.to_s.underscore)
        Statter.dogstatsd&.increment('sidekiq.enqueue.retry', dd_options)
      end

      Statter.dogstatsd&.increment('sidekiq.error', dd_options)
      Statter.statsd.increment(metric_name(worker, 'error'))

      raise e
    ensure
      WorkerMetrics.trace_workers_decrement_counter(worker.class.to_s.underscore)
      Statter.dogstatsd&.flush(sync: true)
    end

    private

    # returns -1 if no retries have been attempted
    def current_retries(job)
      job["retry_count"] || -1
    end
  
    def is_retry(job)
      current_retries(job) >= 0
    end
  end
end
