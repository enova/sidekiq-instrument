require 'sidekiq/instrument/middleware/server'

RSpec.describe Sidekiq::Instrument::ServerMiddleware do
  before do
    Sidekiq::Testing.server_middleware do |chain|
      chain.add described_class
    end
  end

  after(:all) do
    Sidekiq::Testing.server_middleware do |chain|
      chain.remove described_class
    end
  end

  class MyWorker
    include Sidekiq::Worker

    def perform; end
  end

  describe '#call' do
    it 'increments dequeue counter' do
      expect {
        MyWorker.perform_async
      }.to trigger_statsd_increment('shared.sidekiq.default.MyWorker.dequeue')
    end

    it 'measures job runtime' do
      expect {
        MyWorker.perform_async
      }.to trigger_statsd_measure('shared.sidekiq.default.MyWorker.runtime')
    end

    context 'when a job fails' do
      before { allow_any_instance_of(MyWorker).to receive(:perform).and_raise 'foo' }

      it 'increments the failure counter' do
        expect {
          MyWorker.perform_async rescue nil
        }.to trigger_statsd_increment('shared.sidekiq.default.MyWorker.error')
      end

      it 're-raises the error' do
        expect { MyWorker.perform_async }.to raise_error 'foo'
      end
    end
  end
end
