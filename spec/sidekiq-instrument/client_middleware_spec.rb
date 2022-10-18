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
      it 'increments the enqueue counter' do
        expect {
          MyWorker.perform_async
        }.to trigger_statsd_increment('shared.sidekiq.default.MyWorker.enqueue')
      end
    end

    context 'with statsd_metric_name' do
      it 'increments the enqueue counter' do
        expect {
          MyOtherWorker.perform_async
        }.to trigger_statsd_increment('my_other_worker.enqueue')
      end
    end

    context 'dogstatsD' do
      it 'increments the enqueue counter' do
        expect(DogStatsD).to receive(:increment).with('shared.sidekiq.default.MyWorker.enqueue', tags: ['sidekiq']).once
        MyWorker.perform_async
      end
    end
  end
end
