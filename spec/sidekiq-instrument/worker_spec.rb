require 'sidekiq/instrument/worker'

RSpec.describe Sidekiq::Instrument::Worker do
  describe '#perform' do
    let(:worker) { described_class.new }

    it 'triggers the correct default gauges' do
      expect { worker.perform }.to trigger_statsd_gauge('shared.sidekiq.stats.processed')
      expect { worker.perform }.to trigger_statsd_gauge('shared.sidekiq.stats.workers')
      expect { worker.perform }.to trigger_statsd_gauge('shared.sidekiq.stats.pending')
      expect { worker.perform }.to trigger_statsd_gauge('shared.sidekiq.stats.failed')
      expect { worker.perform }.to trigger_statsd_gauge('shared.sidekiq.stats.working')
    end

    it 'allows overriding gauges via constant' do
      stub_const("#{described_class}::METRIC_NAMES", { enqueued: nil })

      expect { worker.perform }.to trigger_statsd_gauge('shared.sidekiq.stats.enqueued')
      expect { worker.perform }.to trigger_statsd_gauge('shared.sidekiq.stats.working')
    end

    context 'when jobs in queues' do
      before do
        Sidekiq::Testing.disable! do
          Sidekiq::Queue.all.each(&:clear)
          MyWorker.perform_async
        end
      end

      it 'gauges the size of the queues' do
        expect { worker.perform }.to trigger_statsd_gauge('shared.sidekiq.default.size')
      end
    end
  end
end
