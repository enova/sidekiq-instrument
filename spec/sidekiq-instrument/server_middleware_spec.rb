require 'sidekiq/instrument/middleware/server'

RSpec.describe Sidekiq::Instrument::ServerMiddleware do
  describe '#call' do
    let(:expected_dog_options) { { tags: ['queue:default', 'worker:my_worker'] } }
    let(:worker_metric_name) do
      'sidekiq_instrument_trace_workers::in_queue'
    end

    before(:all) do
      Sidekiq::Testing.server_middleware do |chain|
        chain.add described_class
      end
    end

    before(:each) do
      Redis.new.flushall
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
        expect(
          Sidekiq::Instrument::Statter.dogstatsd
          ).to receive(:increment).with('sidekiq.dequeue', expected_dog_options).once
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
        it 'increments the in queue counter' do
          Sidekiq::Instrument::WorkerMetrics.enabled = true
          Redis.new.hdel worker_metric_name ,'my_other_worker'
          MyOtherWorker.perform_async
          expect(Redis.new.hget worker_metric_name ,'my_other_worker').to eq('-1')
        end
      end

      context 'with WorkerMetrics.enabled true and an errored job' do
        it 'decrements the in queue counter' do
          Sidekiq::Instrument::WorkerMetrics.enabled = true
          MyOtherWorker.perform_async
          expect(Redis.new.hget worker_metric_name ,'my_other_worker').to eq('-1')
          MyOtherWorker.perform_async rescue nil
          expect(Redis.new.hget worker_metric_name ,'my_other_worker').to eq('-2')
        end
      end
    end

    context 'when a job fails' do
      before do
        allow_any_instance_of(MyWorker).to receive(:perform).and_raise('foo')
      end

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

      it 'does not increase the redis counter' do
        expect(Redis.new.hget worker_metric_name ,'my_worker').to eq(nil)
        MyWorker.perform_async rescue nil
      end

      it 're-raises the error' do
        expect { MyWorker.perform_async }.to raise_error 'foo'
      end

      it 'calls the decrement counter' do
        expect(Sidekiq::Instrument::WorkerMetrics).to receive(:trace_workers_decrement_counter).with('my_worker').once
        MyWorker.perform_async rescue nil
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
