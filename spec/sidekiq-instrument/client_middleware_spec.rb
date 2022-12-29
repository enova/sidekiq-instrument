require 'sidekiq/instrument/middleware/client'

RSpec.describe Sidekiq::Instrument::ClientMiddleware do
  describe '#call' do
    before(:all) do
      Sidekiq.configure_client do |c|
        c.client_middleware do |chain|
          chain.add described_class
        end
      end
    end

    after(:all) do
      Sidekiq.configure_client do |c|
        c.client_middleware do |chain|
          chain.remove described_class
        end
      end
    end

    context 'without statsd_metric_name' do
      it 'increments the StatsD enqueue counter' do
        expect {
          MyWorker.perform_async
        }.to trigger_statsd_increment('shared.sidekiq.default.MyWorker.enqueue')
      end

      it 'increments the DogStatsD enqueue counter' do
        expect(Sidekiq::Instrument::Statter.dogstatsd).to receive(:increment).with('sidekiq.enqueue', { tags: ['queue:default', 'worker:my_worker'] }).once
        MyWorker.perform_async
      end
    end

    context 'with statsd_metric_name' do
      it 'increments the enqueue counter' do
        expect {
          MyOtherWorker.perform_async
        }.to trigger_statsd_increment('my_other_worker.enqueue')
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

    context 'with fakemiddleware error' do
      before do
        Sidekiq.configure_client do |c|
          c.client_middleware do |chain|
            chain.add FakeMiddleware
          end
        end
      end

      after do
        Sidekiq.configure_client do |c|
          c.client_middleware do |chain|
            chain.remove FakeMiddleware
          end
        end
      end

      class FakeMiddleware
        def call(worker_class, job, queue, redis_pool)
          raise 'fake error'
        end
      end

      it 'does not increment the enqueue stat' do
        expect(Sidekiq::Instrument::Statter.dogstatsd).not_to receive(:increment)
        expect { MyWorker.perform_async }.to raise_error('fake error')
      end
    end

    context 'with fakemiddleware error' do
      it 'does increment the enqueue stat' do
        expect(Sidekiq::Instrument::Statter.dogstatsd).to receive(:increment)
        expect { MyWorker.perform_async }.not_to raise_error
      end
    end
  end
end
