module Sidekiq::Instrument
  module MetricNames
    def metric_name(worker, event)
      if worker.respond_to?(:statsd_metric_name)
        worker.send(:statsd_metric_name, event)
      else
        "shared.sidekiq.#{queue_name(worker)}.#{class_name(worker)}.#{event}"
      end
    end

    def worker_dog_options(worker, job)
      tags = job.dig('tags') || []
      {
        tags: [
          "queue:#{queue_name(worker)}",
          "worker:#{underscore(class_name(worker))}"
        ].concat(tags)
      }
    end

    def max_retries(worker)
      retries = fetch_worker_retry(worker)
      case retries.to_s
      when "true", ""
        Sidekiq[:max_retries]
      when "false"
        0
      else
        retries
      end
    end

    private

    def queue_name(worker)
      worker.class.get_sidekiq_options['queue']
    end

    def class_name(worker)
      worker.class.name.gsub('::', '_')
    end

    def fetch_worker_retry(worker)
      worker.class.get_sidekiq_options['retry']
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
