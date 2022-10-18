require 'sidekiq/instrument/mixin'

module Sidekiq::Instrument
  class ServerMiddleware
    include Sidekiq::Instrument::MetricNames

    def call(worker, job, queue, &block)
      StatsD.increment(metric_name(worker, 'dequeue'))
      DogStatsD.increment(metric_name(worker, 'dequeue'), tags: ['sidekiq'])

      StatsD.measure(metric_name(worker, 'runtime'), &block)
      DogStatsD.time(metric_name(worker, 'runtime'), tags: ['sidekiq'])
    rescue StandardError => e
      StatsD.increment(metric_name(worker, 'error'))
      DogStatsD.increment(metric_name(worker, 'error'), tags: ['sidekiq'])
      raise e
    end
  end
end

