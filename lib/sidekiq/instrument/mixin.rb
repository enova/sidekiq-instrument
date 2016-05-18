module Sidekiq::Instrument
  module MetricNames
    def metric_name(worker, event)
      if worker.respond_to?(:statsd_metric_name)
        worker.send(:statsd_metric_name, event)
      else
        queue = worker.sidekiq_options_hash['queue']
        name = worker.class.name

        "shared.sidekiq.#{queue}.#{name}.#{event}"
      end
    end
  end
end
