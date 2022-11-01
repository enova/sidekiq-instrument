require 'sidekiq'
require 'sidekiq/api'

module Sidekiq::Instrument
  class Worker
    include Sidekiq::Worker

    # These defaults are for compatibility with Resque's stats names
    # (i.e. the metrics will reported as :processed, :workers, :pending, and :failed).
    # Feel free to override.
    METRIC_NAMES = {
      processed:    nil,
      workers_size: :workers,
      enqueued:     :pending,
      failed:       nil
    }

    def perform
      info = Sidekiq::Stats.new

      self.class::METRIC_NAMES.each do |method, stat|
        stat ||= method

        Statter.statsd.gauge("shared.sidekiq.stats.#{stat}", info.send(method))
        Statter.dogstatsd&.gauge("sidekiq.#{stat}", info.send(method))
      end

      working = Sidekiq::ProcessSet.new.select { |p| p[:busy] == 1 }.count
      Statter.statsd.gauge('shared.sidekiq.stats.working', working)
      Statter.dogstatsd&.gauge('sidekiq.working', working)

      info.queues.each do |name, size|
        Statter.statsd.gauge("shared.sidekiq.#{name}.size", size)
        Statter.dogstatsd&.gauge('sidekiq.queue.size', size, tags: ["queue:#{name}"])
      end

      Sidekiq::Queue.all.each do |queue|
        Statter.statsd.gauge("shared.sidekiq.#{queue.name}.latency", queue.latency)
        Statter.dogstatsd&.gauge('sidekiq.queue.latency', queue.latency, tags: ["queue:#{queue.name}"])
      end
    end
  end
end
