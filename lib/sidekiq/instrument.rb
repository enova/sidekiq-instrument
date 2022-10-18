require 'active_support/core_ext/class/attribute'

require "sidekiq/instrument/statter"
require "sidekiq/instrument/version"
require "sidekiq/instrument/worker"
require "sidekiq/instrument/middleware/client"
require "sidekiq/instrument/middleware/server"

module Sidekiq
  module Instrument
  end
end
