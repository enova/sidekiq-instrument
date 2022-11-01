module Sidekiq::Instrument
  module MetricNames
    def metric_name(worker, event)
      if worker.respond_to?(:statsd_metric_name)
        worker.send(:statsd_metric_name, event)
      else
        "shared.sidekiq.#{queue_name(worker)}.#{class_name(worker)}.#{event}"
      end
    end

    def worker_dog_options(worker)
      { tags: ["queue:#{queue_name(worker)}", "worker:#{class_name(worker)}"] }
    end

    private

    def queue_name(worker)
      worker.class.get_sidekiq_options['queue']
    end

    def class_name(worker)
      worker.class.name.gsub('::', '_')
    end
  end
end
