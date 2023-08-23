# frozen_string_literal: true

require 'sidekiq'
require 'sidekiq/api'

module Sidekiq::Instrument
  class Worker
    include Sidekiq::Worker

    # These defaults are for compatibility with Resque's stats names
    # (i.e. the metrics will reported as :processed, :workers, :pending, and :failed).
    # Feel free to override.
    METRIC_NAMES = {
      processed: nil,
      workers_size: :workers,
      enqueued: :pending,
      failed: nil
    }.freeze

    def perform
      statter = Sidekiq::Stats.new
      
      self.class::METRIC_NAMES.each do |method, stat|
        emit_stats(statter, method, stat)
      end

      # TODO: workers_size and working are the same, can we drop this?
      emit_stats(statter, :workers_size, :working)

      send_worker_metrics

      Sidekiq::Queue.all.each do |queue|
        Statter.statsd.gauge("shared.sidekiq.#{queue.name}.size", queue.size)
        Statter.dogstatsd&.gauge('sidekiq.queue.size', queue.size, tags: dd_tags(queue))

        Statter.statsd.gauge("shared.sidekiq.#{queue.name}.latency", queue.latency)
        Statter.dogstatsd&.gauge('sidekiq.queue.latency', queue.latency, tags: dd_tags(queue))
      end

      Statter.dogstatsd&.flush(sync: true)
    end

    private

    # @param [Sidekiq::Queue] queue used for stats emission
    # @return [Array<String>] an array of tags
    # @example this method can be override to add more tags
    #   class MyStatsWorker < Sidekiq::Instrument::Worker
    #     private
    #
    #     def dd_tags(queue)
    #       custom_tags = []
    #       queue_type = queue.name.match?(/readonly$/) ? 'read_only'  : 'regular'
    #       custom_tags << "queue_type:#{queue_type}"
    #
    #       super(queue) | custom_tags
    #     end
    #   end
    def dd_tags(queue)
      ["queue:#{queue.name}"]
    end

    def emit_stats(statter, method, stat)
      stat ||= method

      Statter.statsd.gauge("shared.sidekiq.stats.#{stat}", statter.send(method))
      Statter.dogstatsd&.gauge("sidekiq.#{stat}", statter.send(method))
    end
    

    def send_worker_metrics
      return unless WorkerMetrics.enabled

      WorkerMetrics.workers_in_queue.each do |key, value|
        Statter.statsd.gauge("shared.sidekiq.worker_metrics.in_queue.#{key}", value)
        Statter.dogstatsd&.gauge('shared.sidekiq.worker_metrics.in_queue', value, tags: ["worker:#{key}"])
      end
    end
  end
end
