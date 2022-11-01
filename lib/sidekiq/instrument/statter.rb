module Sidekiq::Instrument
  class Statter
    # @!scope class
    # @!attribute [rw]
    # StatsD client for emitting metrics related to Sidekiq queue operations.
    class_attribute :statsd

    # @!scope class
    # @!attribute [rw]
    # Optional DogStatsD client for emitting metrics related to Sidekiq queue operations.
    class_attribute :dogstatsd

    self.statsd ||= StatsD
  end
end
