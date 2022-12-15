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
      { tags: ["queue:#{queue_name(worker)}", "worker:#{underscore(class_name(worker))}"] }
    end

    private

    def queue_name(worker)
      worker.class.get_sidekiq_options['queue']
    end

    def class_name(worker)
      worker.class.name.gsub('::', '_')
    end

    def underscore(string)
      string.gsub(/::/, '/').
        gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
        gsub(/([a-z\d])([A-Z])/,'\1_\2').
        tr("-", "_").
        downcase
    end
  end
end
