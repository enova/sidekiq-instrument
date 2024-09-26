# Sidekiq::Instrument

Reports job metrics using Shopify's [statsd-instrument][statsd-instrument] library and \[optionally\] DataDog's [dogstatsd-ruby](https://github.com/DataDog/dogstatsd-ruby), incrementing a counter for each enqueue and dequeue per job type, and timing the full runtime of your perform method.

## Installation

Add the following to your application's Gemfile:

```ruby
gem 'sidekiq-instrument'
gem 'dogstatsd-ruby' # optional
```

And then execute:

    $ bundle

Or install the gem(s) yourself as:

    $ gem install sidekiq-instrument
    $ gem install dogstatsd-ruby # again, optional

## Usage

For now, this library assumes you have already initialized `StatsD` on your own;
the `statsd-instrument` gem may have chosen reasonable defaults for you already. If not,
a typical Rails app would just use an initializer and set the `StatsD` and optional `DogStatsD`
clients via this gem's `Statter` class:

### StatsD

```ruby
# config/initializers/statsd.rb
require 'statsd-instrument'
StatsD.prefix  = 'my-app'
StatsD.backend = StatsD::Instrument::Backends::UDPBackend.new('some-server:8125')
```

### DogStatsD

```ruby
# config/initializers/dogstatsd.rb
require 'datadog/statsd'
DogStatsD = Datadog::Statsd.new('localhost', 8125, tags: {app_name: 'my_app', env: 'production'})
```

Then add the client and server middlewares in your Sidekiq initializer:

```ruby
require 'sidekiq/instrument'

Sidekiq::Instrument::Statter.statsd = StatsD # optional, Statter will fall back to a global StatsD
Sidekiq::Instrument::Statter.dogstatsd = DogStatsD # optional, dogstatsd can be nil if not desired

Sidekiq.configure_server do |config|
  config.server_middleware do |chain|
    chain.add Sidekiq::Instrument::ServerMiddleware
  end

  config.client_middleware do |chain|
    chain.add Sidekiq::Instrument::ClientMiddleware
  end
end

Sidekiq.configure_client do |config|
  config.client_middleware do |chain|
    chain.add Sidekiq::Instrument::ClientMiddleware
  end
end

Sidekiq::Instrument::WorkerMetrics.enabled = true # Set true to enable worker metrics
Sidekiq::Instrument::WorkerMetrics.namespace = <APP_NAME>
```

## StatsD Keys
For each job, the following metrics will be reported:

1. **shared.sidekiq._queue_._job_.schedule**: counter incremented each time a
   job is scheduled to be pushed onto the queue later.
2. **shared.sidekiq._queue_._job_.enqueue**: counter incremented each time a
   job is pushed onto the queue.
3. **shared.sidekiq._queue_._job_.dequeue**: counter incremented just before
   worker begins performing a job.
4. **shared.sidekiq._queue_._job_.runtime**: timer of the total time spent
   in `perform`, in milliseconds.
5. **shared.sidekiq._queue_._job_.error**: counter incremented each time a
   job fails.

For job retry attempts, metrics 2-5 will still be reported but the enqueue/dequeue metrics
will have a `.retry` appended:

1. **shared.sidekiq._queue_._job_.enqueue.retry**
2. **shared.sidekiq._queue_._job_.dequeue.retry**

The metric names can be changed by overriding the `statsd_metric_name`
method in your worker classes.

For each queue, the following metrics will be reported:
1. **shared.sidekiq._queue_.size**: gauge of how many jobs are in the queue
2. **shared.sidekiq._queue_.latency**: gauge of how long the oldest job has been in the queue

For each worker, the following metrics and tags will be reported:
1. **sidekiq.worker_metrics.in_queue.#{key}**: number of jobs "in queue" per worker, uses redis to track increment/decrement (**this metric is currently inaccurate**)

## DogStatsD Keys
For each job, the following metrics and tags will be reported:

1. **sidekiq.schedule (tags: {queue: _queue_, worker: _job_})**: counter incremented each time a
   job is scheduled to be pushed onto the queue later.
2. **sidekiq.enqueue (tags: {queue: _queue_, worker: _job_})**: counter incremented each time a
   job is pushed onto the queue.
3. **sidekiq.dequeue (tags: {queue: _queue_, worker: _job_})**: counter incremented just before
   worker begins performing a job.
4. **sidekiq.runtime (tags: {queue: _queue_, worker: _job_})**: timer of the total time spent
   in `perform`, in milliseconds.
5. **sidekiq.error (tags: {queue: _queue_, worker: _job_, error: _errorclass_})**: counter incremented each time a
   job fails.

For job retry attempts, the above 4 metrics will still be reported but the enqueue/dequeue metrics
will have a `.retry` appended:

1. **sidekiq.enqueue.retry (tags: {queue: _queue_, worker: _job_})**
2. **sidekiq.dequeue.retry (tags: {queue: _queue_, worker: _job_})**

For each queue, the following metrics and tags will be reported:
1. **sidekiq.queue.size (tags: {queue: _queue_})**: gauge of how many jobs are in the queue
2. **sidekiq.queue.latency (tags: {queue: _queue_})**: gauge of how long the oldest job has been in the queue

For each worker, the following metrics and tags will be reported:
1. **sidekiq.worker_metrics.in_queue.#{key}**: number of jobs "in queue" per worker, uses redis to track increment/decrement (**this metric is currently inaccurate**)

## Worker

**WARNING: The Redis count metrics reported by this Worker are currently inaccurate.**

There is a worker, `Sidekiq::Instrument::Worker`, that submits gauges
for various interesting statistics; namely, the bulk of the information in `Sidekiq::Stats`
and the sizes of each individual queue. While the worker class is a fully valid Sidekiq worker,
you should inherit from it your own job implementation instead of using it directly:

```ruby
# app/jobs/sidekiq_stats_job.rb
class SidekiqStatsJob < Sidekiq::Instrument::Worker
  METRIC_NAMES = %w[
    processed
    failed
  ]

  sidekiq_options queue: :stats
end
```

In this example, we override the default stats with the ones we want reported by defining `METRIC_NAMES`.
This can be either an Array or a Hash (if you also want to map a stat to a different metric name).

You can schedule this however you see fit. A simple way is to use [sidekiq-scheduler][sidekiq-scheduler] to run it every N minutes.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/enova/sidekiq-instrument.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

[statsd-instrument]: https://github.com/Shopify/statsd-instrument
[sidekiq-scheduler]: https://github.com/moove-it/sidekiq-scheduler
