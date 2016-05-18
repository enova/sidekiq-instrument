module Sidekiq::Instrument
  class ServerMiddleware
    include Sidekiq::Instrument::MetricNames

    def call(worker, job, queue, &block)
      StatsD.increment(metric_name(worker, 'dequeue'))

      StatsD.measure(metric_name(worker,'runtime'), &block)
    rescue StandardError => e
      StatsD.increment(metric_name(worker, 'error'))
      raise e
    end
  end
end
