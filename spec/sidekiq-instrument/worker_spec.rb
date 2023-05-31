require 'sidekiq/instrument/worker'

RSpec.describe Sidekiq::Instrument::Worker do
  let(:worker_metric_name) do
    'sidekiq_instrument_trace_workers::in_queue'
  end

  describe '#perform' do
    let(:worker) { described_class.new }

    before do
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
            if ex.include?('shared.sidekiq.worker_metrics.in_queue')
              expect(dogstatsd).to receive(:gauge).with(ex, anything, anything)
            else
              expect(dogstatsd).to receive(:gauge).with(ex, anything)
            end
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

        MyWorker.perform_async

        Sidekiq.configure_client do |c|
          c.client_middleware do |chain|
            chain.remove Sidekiq::Instrument::ClientMiddleware
          end
        end
      end

      it_behaves_like 'worker behavior', %w[
        shared.sidekiq.worker_metrics.in_queue
        sidekiq.processed
        sidekiq.workers
        sidekiq.pending
        sidekiq.failed
        sidekiq.working
      ]
    end
  end

  describe 'client & server middleware' do
    before(:each) do
      Redis.new.flushall
      Sidekiq.configure_client do |c|
        c.client_middleware do |chain|
          chain.add Sidekiq::Instrument::ClientMiddleware
        end
      end
    end

    after(:each) do
      Sidekiq.configure_client do |c|
        c.client_middleware do |chain|
          chain.remove Sidekiq::Instrument::ClientMiddleware
        end
      end
    end

    context 'successful increment' do
      let(:expected_dog_options) { { tags: ['queue:default', 'worker:my_worker'] } }

      before do
        Sidekiq.server_middleware do |chain|
          chain.add Sidekiq::Instrument::ServerMiddleware
        end
      end
  
      after do
        Sidekiq.server_middleware do |chain|
          chain.remove Sidekiq::Instrument::ServerMiddleware
        end
      end

      it 'increments the in queue counter' do
        Sidekiq::Instrument::WorkerMetrics.enabled = true
        redis = Redis.new
        expect(redis.hget(worker_metric_name ,'my_worker')).to be nil
        MyWorker.perform_async
        expect(redis.hget(worker_metric_name ,'my_worker')).to eq('1')
        MyWorker.perform_async
        expect(redis.hget(worker_metric_name ,'my_worker')).to eq('2')
      end

      it 'increments the DogStatsD failure counter' do
        expect(Sidekiq::Instrument::Statter.dogstatsd).to receive(:increment).with('sidekiq.enqueue', expected_dog_options).once
        expect(Sidekiq::Instrument::Statter.dogstatsd).not_to receive(:time)
        MyWorker.perform_async rescue nil
      end

      it 'does not increase the redis counter' do
        expect(Redis.new.hget worker_metric_name ,'my_worker').to eq(nil)
        MyWorker.perform_async rescue nil
      end
    end

    context 'errored decrement' do
      before do
        allow_any_instance_of(MyWorker).to receive(:perform_async).and_raise(StandardError)
        Sidekiq::Testing.server_middleware do |chain|
          chain.add Sidekiq::Instrument::ServerMiddleware
        end
      end
  
      after do
        Sidekiq::Testing.server_middleware do |chain|
          chain.remove Sidekiq::Instrument::ServerMiddleware
        end
      end

      it 'does not increment the in queue counter' do
        Sidekiq::Instrument::WorkerMetrics.enabled = true
        redis = Redis.new
        expect(redis.hget(worker_metric_name ,'my_worker')).to be nil
        MyWorker.perform_async
        expect(redis.hget(worker_metric_name ,'my_worker')).to eq('0')
        MyWorker.perform_async
        expect(redis.hget(worker_metric_name ,'my_worker')).to eq('0')
        redis.hincrby(worker_metric_name, 'my_worker', 1)
        MyWorker.perform_async
        expect(redis.hget(worker_metric_name ,'my_worker')).to eq('1')
      end

      it 'calls the decrement counter' do
        expect(
          Sidekiq::Instrument::WorkerMetrics
          ).to receive(:trace_workers_decrement_counter).with('my_worker').once
        MyWorker.perform_async rescue nil
      end
    end
  end
end
