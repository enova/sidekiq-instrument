# Sidekiq::Instrument

Reports job metrics using Shopify's [statsd-instrument][statsd-instrument] library, incrementing a counter for each enqueue and dequeue per job type, and timing the full runtime of your perform method.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'sidekiq-instrument'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install sidekiq-instrument

## Usage

For now, this library assumes you have already initialized `StatsD` on your own;
the `statsd-instrument` gem may have chosen reasonable defaults for you already. If not,
a typical Rails app would just use an initializer:

```ruby
# config/initializers/statsd.rb
require 'statsd-instrument'
StatsD.prefix  = 'my-app'
StatsD.backend = StatsD::Instrument::Backends::UDPBackend.new('some-server:8125')
```

## StatsD Keys
For each job, the following metrics will be reported:

1. **shared.sidekiq._queue_._job_.enqueue**: counter incremented each time a
   job is pushed onto the queue.
2. **shared.sidekiq._queue_._job_.dequeue**: counter incremented just before
   worker begins performing a job.
3. **shared.sidekiq._queue_._job_.runtime**: timer of the total time spent
   in `perform`, in milliseconds.
3. **shared.sidekiq._queue_._job_.failure**: counter incremented each time a
   job fails.

The metric names can be changed by overriding the `statsd_metric_name`
method after extending your worker with the `Sidekiq::Instrument`
module.

## Worker
There is a worker, `Sidekiq::Instrument::Worker`, that submits gauges
for various interesting statistics; namely, the bulk of the information in `Sidekiq.info`
and the sizes of each individual queue. The module itself is not a fully valid
worker, as it does not know what queue it should live in. You should `include` the
module into your own job implementation:

```ruby
# app/jobs/sidekiq_stats_job.rb
class SidekiqStatsJob
  include Sidekiq::Instrument::Worker

  sidekiq_options queue: :low
end
```

You can schedule this however you see fit. A simple way is to use sidekiq-scheduler to run it every N minutes.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/sidekiq-instrument.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

[statsd-instrument]: https://github.com/Shopify/statsd-instrument
