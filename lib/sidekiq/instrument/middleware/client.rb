module Sidekiq::Instrument
  class ClientMiddleware
    include Sidekiq::Instrument::MetricNames

    def call(worker_class, job, queue, redis_pool)
      StatsD.increment metric_name(worker_class.new, 'enqueue')

      yield
    end
  end
end
