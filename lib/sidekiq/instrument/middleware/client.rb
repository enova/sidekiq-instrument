require 'sidekiq/instrument/mixin'

module Sidekiq::Instrument
  class ClientMiddleware
    include Sidekiq::Instrument::MetricNames

    def call(worker_class, job, queue, redis_pool)
      # worker_class is a const in sidekiq >= 6.x
      klass = Object.const_get(worker_class.to_s)
      StatsD.increment(metric_name(klass.new, 'enqueue'))
      DogStatsD.increment(metric_name(klass.new, 'enqueue'), tags: ['sidekiq'])

      yield
    end
  end
end
