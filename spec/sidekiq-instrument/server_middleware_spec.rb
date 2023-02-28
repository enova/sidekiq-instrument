require 'sidekiq/instrument/middleware/server'

RSpec.describe Sidekiq::Instrument::ServerMiddleware do
  describe '#call' do
    let(:expected_dog_options) { { tags: ['queue:default', 'worker:my_worker'] } }

    before(:all) do
      Sidekiq::Testing.server_middleware do |chain|
        chain.add described_class
      end
    end

    after(:all) do
      Sidekiq::Testing.server_middleware do |chain|
        chain.remove described_class
      end
    end

    context 'when a job succeeds' do
      it 'increments StatsD dequeue counter' do
        expect {
          MyWorker.perform_async
        }.to trigger_statsd_increment('shared.sidekiq.default.MyWorker.dequeue')
      end

      it 'increments DogStatsD dequeue counter' do
        expect(Sidekiq::Instrument::Statter.dogstatsd).to receive(:increment).with('sidekiq.dequeue', expected_dog_options).once
        MyWorker.perform_async
      end

      it 'measures StatsD job runtime' do
        expect {
          MyWorker.perform_async
        }.to trigger_statsd_measure('shared.sidekiq.default.MyWorker.runtime')
      end

      it 'measures DogStatsD job runtime' do
        expect(Sidekiq::Instrument::Statter.dogstatsd).to receive(:timing).once
        MyWorker.perform_async
      end

      context 'with WorkerMetrics.enabled true' do
        let(:worker_metric_name) do
          "sidekiq_instrument_trace_workers::in_queue"
        end
        it 'increments the enqueue counter' do
            Sidekiq::Instrument::WorkerMetrics.enabled = true
            Sidekiq::Instrument::WorkerMetrics.redis_config = {
              host:        ENV['REDIS_HOST'],
              port:        ENV['REDIS_PORT'],
              db:          0
            }
            Redis.new.hdel worker_metric_name ,'MyOtherWorker'
            MyOtherWorker.perform_async
            expect(
            Redis.new.hget worker_metric_name ,'MyOtherWorker'
          ).to eq('-1')
        end
      end

      context 'with WorkerMetrics.enabled true, and redis_config not given' do
        let(:worker_metric_name) do
          "sidekiq_instrument_trace_workers::in_queue"
        end
        it 'increments the enqueue counter' do
            Sidekiq::Instrument::WorkerMetrics.enabled = true
            Redis.new.hdel worker_metric_name ,'MyOtherWorker'
            MyOtherWorker.perform_async
            expect(
            Redis.new.hget worker_metric_name ,'MyOtherWorker'
          ).to eq('-1')
        end
      end
    end

    context 'when a job fails' do
      before { allow_any_instance_of(MyWorker).to receive(:perform).and_raise('foo') }

      it 'increments the StatsD failure counter' do
        expect {
          MyWorker.perform_async rescue nil
        }.to trigger_statsd_increment('shared.sidekiq.default.MyWorker.error')
      end

      it 'increments the DogStatsD failure counter' do
        expect(Sidekiq::Instrument::Statter.dogstatsd).to receive(:increment).with('sidekiq.dequeue', expected_dog_options).once
        expect(Sidekiq::Instrument::Statter.dogstatsd).not_to receive(:time)
        expect(Sidekiq::Instrument::Statter.dogstatsd).to receive(:increment).with('sidekiq.error', expected_dog_options).once
        MyWorker.perform_async rescue nil
      end

      it 're-raises the error' do
        expect { MyWorker.perform_async }.to raise_error 'foo'
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
  end
end
