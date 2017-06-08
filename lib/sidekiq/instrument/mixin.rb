module Sidekiq::Instrument
  module MetricNames
    def metric_name(worker, event)
      if worker.respond_to?(:statsd_metric_name)
        worker.send(:statsd_metric_name, event)
      else
        queue = worker.class.get_sidekiq_options['queue']
        name = worker.class.name.gsub('::', '_')

        "shared.sidekiq.#{queue}.#{name}.#{event}"
      end
    end
  end
end
