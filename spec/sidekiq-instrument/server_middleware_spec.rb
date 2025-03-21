# frozen_string_literal: true

require 'sidekiq/instrument/middleware/server'

RSpec.describe Sidekiq::Instrument::ServerMiddleware do
  describe '#call' do
    let(:expected_dog_options) { { tags: ['queue:default', 'worker:my_worker'] } }
    let(:expected_error_dog_options) { { tags: ['queue:default', 'worker:my_worker', 'error:RuntimeError'] } }

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

    context 'when an initial job succeeds' do
      before do
        Sidekiq[:max_retries] = 0
      end

      it 'increments StatsD dequeue and success counters' do
        expect do
          MyWorker.perform_async
        end.to trigger_statsd_increment('shared.sidekiq.default.MyWorker.dequeue') &&
               trigger_statsd_increment('shared.sidekiq.default.MyWorker.success')
      end

      it 'increments DogStatsD dequeue and success counters' do
        expect(
          Sidekiq::Instrument::Statter.dogstatsd
        ).to receive(:increment).with('sidekiq.dequeue', expected_dog_options).once
        expect(
          Sidekiq::Instrument::Statter.dogstatsd
        ).to receive(:increment).with('sidekiq.success', expected_dog_options).once
        MyWorker.perform_async
      end

      it 'measures StatsD job runtime' do
        expect do
          MyWorker.perform_async
        end.to trigger_statsd_measure('shared.sidekiq.default.MyWorker.runtime')
      end

      it 'measures DogStatsD job runtime' do
        expect(Sidekiq::Instrument::Statter.dogstatsd).to receive(:timing).once
        MyWorker.perform_async
      end

      context 'with additional tag(s)' do
        let(:tag) { 'test_worker' }
        let(:expected_dog_options) { { tags: ['queue:default', 'worker:my_worker', tag] } }

        it 'increments DogStatsD dequeue counter with additional tag(s)' do
          expect(
            Sidekiq::Instrument::Statter.dogstatsd
          ).to receive(:increment).with('sidekiq.dequeue', expected_dog_options).once
          expect(
            Sidekiq::Instrument::Statter.dogstatsd
          ).to receive(:increment).with('sidekiq.success', expected_dog_options).once
          MyWorker.set(tags: [tag]).perform_async
        end
      end

      # TODO: These tests are meaningless until we fix the WorkerMetrics class
      #
      # context 'with WorkerMetrics.enabled true' do
      #   it 'decrements the in_queue counter' do
      #     Sidekiq::Instrument::WorkerMetrics.enabled = true
      #     Redis.new.hdel(worker_metric_name, 'my_other_worker')
      #     MyOtherWorker.perform_async
      #     expect(Redis.new.hget(worker_metric_name, 'my_other_worker')).to eq('-1')
      #   end
      # end

      # context 'with WorkerMetrics.enabled true and an errored job' do
      #   it 'decrements the in_queue counter' do
      #     Sidekiq::Instrument::WorkerMetrics.enabled = true
      #     MyOtherWorker.perform_async
      #     expect(Redis.new.hget(worker_metric_name, 'my_other_worker')).to eq('-1')
      #     begin
      #       MyOtherWorker.perform_async
      #     rescue StandardError
      #       nil
      #     end
      #     expect(Redis.new.hget(worker_metric_name, 'my_other_worker')).to eq('-2')
      #   end
      # end
    end

    context 'when a retried job succeeds' do
      before do
        Sidekiq[:max_retries] = 1
        allow_any_instance_of(MyWorker).to receive(:perform).and_raise(RuntimeError.new('foo'))

        # This makes the job look like a retry since we can't access the job argument
        allow_any_instance_of(Sidekiq::Instrument::ServerMiddleware).to receive(:current_retries).and_return(0)
      end

      it 'increments StatsD dequeue.retry counter' do
        expect do
          MyWorker.perform_async
        rescue StandardError
          nil
        end.to trigger_statsd_increment('shared.sidekiq.default.MyWorker.dequeue.retry')
      end

      it 'increments DogStatsD dequeue.retry counter' do
        expect do
          MyWorker.perform_async
        rescue StandardError
          expect(
            Sidekiq::Instrument::Statter.dogstatsd
          ).to receive(:increment).with('sidekiq.dequeue.retry', expected_dog_options).once
        end
      end
    end

    context 'when a job fails' do
      before do
        Sidekiq[:max_retries] = 0
        allow_any_instance_of(MyWorker).to receive(:perform).and_raise(RuntimeError.new('foo'))
      end

      it 'increments the StatsD error counter' do
        expect do
          MyWorker.perform_async
        rescue StandardError
          nil
        end.to trigger_statsd_increment('shared.sidekiq.default.MyWorker.error')
      end

      it 'increments the DogStatsD error counter' do
        expect(
          Sidekiq::Instrument::Statter.dogstatsd
        ).to receive(:increment).with('sidekiq.dequeue', expected_dog_options).once
        expect(Sidekiq::Instrument::Statter.dogstatsd).not_to receive(:time)
        expect(
          Sidekiq::Instrument::Statter.dogstatsd
        ).to receive(:increment).with('sidekiq.error', expected_error_dog_options).once

        begin
          MyWorker.perform_async
        rescue StandardError
          nil
        end
      end

      context 'with additional tag(s)' do
        let(:tag) { 'test_worker' }
        let(:expected_dog_options) { { tags: ['queue:default', 'worker:my_worker', tag] } }
        let(:expected_error_dog_options) { { tags: ['queue:default', 'worker:my_worker', tag, 'error:RuntimeError'] } }

        it 'increments DogStatsD dequeue counter with additional tag(s)' do
          expect(
            Sidekiq::Instrument::Statter.dogstatsd
          ).to receive(:increment).with('sidekiq.dequeue', expected_dog_options).once
          expect(Sidekiq::Instrument::Statter.dogstatsd).not_to receive(:time)
          expect(
            Sidekiq::Instrument::Statter.dogstatsd
          ).to receive(:increment).with('sidekiq.error', expected_error_dog_options).once

          begin
            MyWorker.set(tags: [tag]).perform_async
          rescue StandardError
            nil
          end
        end
      end

      context 'when the worker has retries disabled' do
        shared_examples 'it does not attempt to track retries' do |retry_value|
          before do
            Sidekiq[:max_retries] = 1
            allow(MyWorker).to receive(:get_sidekiq_options).and_return({ "retry" => retry_value, "queue" => 'default' })
          end

          it 'does not increment the DogStatsD enqueue.retry counter' do
            expect(
              Sidekiq::Instrument::Statter.dogstatsd
            ).to receive(:increment).with('sidekiq.dequeue', expected_dog_options).once
            expect(
              Sidekiq::Instrument::Statter.dogstatsd
            ).not_to receive(:increment).with('sidekiq.enqueue.retry', expected_error_dog_options)
            expect(Sidekiq::Instrument::Statter.dogstatsd).not_to receive(:time)
            expect(
              Sidekiq::Instrument::Statter.dogstatsd
            ).to receive(:increment).with('sidekiq.error', expected_error_dog_options).once

            begin
              MyWorker.perform_async
            rescue StandardError
              nil
            end
          end
        end

        it_behaves_like 'it does not attempt to track retries', false

        it_behaves_like 'it does not attempt to track retries', 'false'

        it_behaves_like 'it does not attempt to track retries', 0
      end

      context 'when the current job has retries left to attempt' do
        shared_examples 'it tracks the retries with DogStatsD' do |retry_value|
          before do
            Sidekiq[:max_retries] = 2
            allow(MyWorker).to receive(:get_sidekiq_options).and_return({ "retry" => retry_value, "queue" => 'default' })
          end

          it 'increments the DogStatsD enqueue.retry counter' do
            expect(
              Sidekiq::Instrument::Statter.dogstatsd
            ).to receive(:increment).with('sidekiq.dequeue', expected_dog_options).once
            expect(
              Sidekiq::Instrument::Statter.dogstatsd
            ).to receive(:increment).with('sidekiq.enqueue.retry', expected_error_dog_options).once
            expect(Sidekiq::Instrument::Statter.dogstatsd).not_to receive(:time)
            expect(
              Sidekiq::Instrument::Statter.dogstatsd
            ).to receive(:increment).with('sidekiq.error', expected_error_dog_options).once

            begin
              MyWorker.perform_async
            rescue StandardError
              nil
            end
          end
        end

        it_behaves_like 'it tracks the retries with DogStatsD', 'true'

        it_behaves_like 'it tracks the retries with DogStatsD', true

        it_behaves_like 'it tracks the retries with DogStatsD', 5

        it_behaves_like 'it tracks the retries with DogStatsD', nil
      end

      context 'when the job is on its last retry attempt' do
        before do
          Sidekiq[:max_retries] = 1

          # This makes the job look like a retry since we can't access the job argument
          allow_any_instance_of(Sidekiq::Instrument::ServerMiddleware).to receive(:current_retries).and_return(1)
        end

        it 'increments the DogStatsD dequeue.retry counter but not the enqueue.retry counter' do
          expect(
            Sidekiq::Instrument::Statter.dogstatsd
          ).to receive(:increment).with('sidekiq.dequeue.retry', expected_dog_options).once
          expect(Sidekiq::Instrument::Statter.dogstatsd).not_to receive(:time)
          expect(
            Sidekiq::Instrument::Statter.dogstatsd
          ).to receive(:increment).with('sidekiq.error', expected_error_dog_options).once

          begin
            MyWorker.perform_async
          rescue StandardError
            nil
          end
        end
      end

      it 're-raises the error' do
        expect { MyWorker.perform_async }.to raise_error 'foo'
      end

      it 'calls the decrement counter' do
        expect(
          Sidekiq::Instrument::WorkerMetrics
        ).to receive(:trace_workers_decrement_counter).with('my_worker').once
        begin
          MyWorker.perform_async
        rescue StandardError
          nil
        end
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
