# frozen_string_literal: true

require 'sidekiq/instrument/middleware/client'

RSpec.describe Sidekiq::Instrument::ClientMiddleware do
  describe '#call' do
    let(:worker_metric_name) do
      'sidekiq_instrument_trace_workers::in_queue'
    end

    before(:all) do
      Sidekiq.configure_client do |c|
        c.client_middleware do |chain|
          chain.add described_class
        end
      end
    end

    before(:each) do
      Redis.new.flushall
    end

    after(:all) do
      Sidekiq.configure_client do |c|
        c.client_middleware do |chain|
          chain.remove described_class
        end
      end
    end

    context 'with Sidekiq::Context.current[:class] (job being enqueued)' do
      before do
        Sidekiq::Context.current[:class] = 'MyWorker'
      end

      context 'without statsd_metric_name' do
        it 'increments the StatsD enqueue counter' do
          expect do
            MyWorker.perform_async
          end.to trigger_statsd_increment('shared.sidekiq.default.MyWorker.enqueue')
        end

        it 'increments the DogStatsD enqueue counter' do
          expect(
            Sidekiq::Instrument::Statter.dogstatsd
          ).to receive(:increment).with('sidekiq.enqueue', { tags: ['queue:default', 'worker:my_worker'] }).once
          MyWorker.perform_async
        end

        context 'with additional tag(s)' do
          it 'increments DogStatsD enqueue counter with additional tag(s)' do
            tag = 'test_worker'

            expect(
              Sidekiq::Instrument::Statter.dogstatsd
            ).to receive(:increment).with('sidekiq.enqueue', { tags: ['queue:default', 'worker:my_worker', tag] }).once
            MyWorker.set(tags: [tag]).perform_async
          end
        end
      end

      context 'with statsd_metric_name' do
        it 'does the enqueue counter' do
          expect do
            MyOtherWorker.perform_async
          end.to trigger_statsd_increment('my_other_worker.enqueue')
        end
      end

      context 'with WorkerMetrics.enabled true' do
        it 'increments the in_queue counter' do
          Sidekiq::Instrument::WorkerMetrics.enabled = true
          MyOtherWorker.perform_async
          expect(Redis.new.hget(worker_metric_name, 'my_other_worker')).to eq('1')
          MyOtherWorker.perform_async
          expect(Redis.new.hget(worker_metric_name, 'my_other_worker')).to eq('2')
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

    context 'without the Sidekiq::Context.current[:class] (job being dequeued)' do
      before do
        Sidekiq::Context.current[:class] = nil
      end

      it 'does not increment the StatsD enqueue counter' do
        expect do
          MyWorker.perform_async
        end.not_to trigger_statsd_increment('shared.sidekiq.default.MyWorker.enqueue')
      end

      it 'does not increment the DogStatsD enqueue counter' do
        expect(
          Sidekiq::Instrument::Statter.dogstatsd
        ).not_to receive(:increment).with('sidekiq.enqueue', { tags: ['queue:default', 'worker:my_worker'] })
        MyWorker.perform_async
      end

      context 'with WorkerMetrics.enabled true' do
        before do
          Redis.new.flushall
          Redis.new.hset(worker_metric_name, 'my_other_worker', 0)
        end

        it 'does not increment the in_queue counter' do
          Sidekiq::Instrument::WorkerMetrics.enabled = true
          MyOtherWorker.perform_async
          expect(Redis.new.hget(worker_metric_name, 'my_other_worker')).to eq('0')
          MyOtherWorker.perform_async
          expect(Redis.new.hget(worker_metric_name, 'my_other_worker')).to eq('0')
        end
      end
    end
  end
end
