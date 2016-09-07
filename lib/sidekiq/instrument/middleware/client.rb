require 'sidekiq/instrument/mixin'

module Sidekiq::Instrument
  class ClientMiddleware
    include Sidekiq::Instrument::MetricNames

    def call(worker_class, job, queue, redis_pool)
      klass = Object.const_get(worker_class)
      StatsD.increment metric_name(klass.new, 'enqueue')

      yield
    end
  end
end
