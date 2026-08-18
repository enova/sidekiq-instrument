require "sidekiq/job_retry"

module Sidekiq::Instrument
  module MetricNames
    def metric_name(worker, job, event)
      if worker.respond_to?(:statsd_metric_name)
        worker.send(:statsd_metric_name, event)
      else
        "shared.sidekiq.#{queue_name(job)}.#{class_name(worker)}.#{event}"
      end
    end

    def worker_dog_options(worker, job)
      {
        tags: [
          "queue:#{queue_name(job)}",
          "worker:#{underscore(class_name(worker))}"
        ].concat(job.fetch('tags', []))
      }
    end

    def max_retries(worker)
      retries = fetch_worker_retry(worker)
      case retries.to_s
      when "true", ""
        if Sidekiq.respond_to?(:default_configuration) # Sidekiq 7.0+
          Sidekiq.default_configuration[:max_retries]
        else                                           # Sidekiq 6
          Sidekiq[:max_retries]
        end || Sidekiq::JobRetry::DEFAULT_MAX_RETRY_ATTEMPTS
      when "false"
        0
      else
        retries
      end
    end

    private

    def queue_name(job)
      job['queue']
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
