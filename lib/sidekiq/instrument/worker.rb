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

        StatsD.gauge("shared.sidekiq.stats.#{stat}", info.send(method))
        DogStatsD.gauge("shared.sidekiq.stats.#{stat}", info.send(method), tags: ['sidekiq'])
      end

      working = Sidekiq::ProcessSet.new.select { |p| p[:busy] == 1 }.count
      StatsD.gauge("shared.sidekiq.stats.working", working)
      DogStatsD.gauge("shared.sidekiq.stats.working", working, tags: ['sidekiq'])

      info.queues.each do |name, size|
        StatsD.gauge("shared.sidekiq.#{name}.size", size)
        DogStatsD.gauge("shared.sidekiq.#{name}.size", size, tags: ['sidekiq'])
      end

      Sidekiq::Queue.all.each do |queue|
        StatsD.gauge("shared.sidekiq.#{queue.name}.latency", queue.latency)
        DogStatsD.gauge("shared.sidekiq.#{queue.name}.latency", queue.latency, tags: ['sidekiq'])
      end
    end
  end
end
