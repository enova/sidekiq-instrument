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

    context 'with DogStatsD client' do
      it 'sends the appropriate metrics via DogStatsD' do
        expect(Sidekiq::Instrument::Statter.dogstatsd).to receive(:gauge).exactly(7).times
        worker.perform
      end
    end

    context 'without optional DogStatsD client' do
      before do
        @tmp = Sidekiq::Instrument::Statter.dogstatsd
        Sidekiq::Instrument::Statter.dogstatsd = nil
      end

      after do
        Sidekiq::Instrument::Statter.dogstatsd = @tmp
      end

      it 'does not error' do
        expect { MyWorker.perform_async }.not_to raise_error
      end
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

      it 'gauges the latency of the queues' do
        expect { worker.perform }.to trigger_statsd_gauge('shared.sidekiq.default.latency')
      end
    end
  end
end
