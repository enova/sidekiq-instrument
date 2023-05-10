require 'sidekiq/instrument/worker'

RSpec.describe Sidekiq::Instrument::Worker do
  describe '#perform' do
    let(:worker) { described_class.new }
    let(:worker_metric_name) do
      "sidekiq_instrument_trace_workers::in_queue"
    end
    before do
      Redis.new.hdel worker_metric_name ,'my_other_worker'
      Redis.new.hdel worker_metric_name ,'my_worker'
    end
    shared_examples 'worker behavior' do |expected_stats|
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
        let(:dogstatsd) { Sidekiq::Instrument::Statter.dogstatsd }

        it 'sends the appropriate metrics via DogStatsD' do
          allow(dogstatsd).to receive(:gauge).with('sidekiq.queue.size', any_args).at_least(:once)
          allow(dogstatsd).to receive(:gauge).with('sidekiq.queue.latency', any_args).at_least(:once)
          expected_stats.each do |ex|
            expect(dogstatsd).to receive(:gauge).with(ex, anything)
          end
          worker.perform
        end
      end

      context 'without optional DogStatsD client' do
        before do
          @tmp = Sidekiq::Instrument::Statter.dogstatsd
          Sidekiq::Instrument::Statter.dogstatsd = nil
          Sidekiq::Instrument::WorkerMetrics.enabled = false
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
    context 'when WorkerMetrics disabled' do
      before do
        Sidekiq::Instrument::WorkerMetrics.enabled = false
      end
      it_behaves_like 'worker behavior', %w[
        sidekiq.processed
        sidekiq.workers
        sidekiq.pending
        sidekiq.failed
        sidekiq.working
      ]
    end

    context 'when WorkerMetrics enabled' do
      before do
        Sidekiq::Instrument::WorkerMetrics.enabled = true
        Sidekiq.configure_client do |c|
          c.client_middleware do |chain|
            chain.add Sidekiq::Instrument::ClientMiddleware
          end
        end

        MyOtherWorker.perform_async

        Sidekiq.configure_client do |c|
          c.client_middleware do |chain|
            chain.remove Sidekiq::Instrument::ClientMiddleware
          end
        end
      end

      it_behaves_like 'worker behavior', %w[
        shared.sidekiq.worker_metrics.inqueue.my_other_worker
        sidekiq.processed
        sidekiq.workers
        sidekiq.pending
        sidekiq.failed
        sidekiq.working
      ]
    end
  end
end
