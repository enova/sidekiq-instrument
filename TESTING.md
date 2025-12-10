# Testing Strategy

## Overview

This gem supports Sidekiq versions 4.2 through 8.x, which span a major transition in Redis client libraries:
- **Sidekiq 4.x-6.x**: Uses `redis` gem 3.x-4.x with classic API
- **Sidekiq 7.x+**: Uses `redis` gem 5.x + `redis-client` gem with new connection pooling

## Testing Approach

### Why We Stub Sidekiq API Classes

We stub `Sidekiq::Stats`, `Sidekiq::Workers`, and `Sidekiq::Queue` rather than using a full Redis mock because:

1. **Version Compatibility**: Works across all Sidekiq versions (4.2-8.x) without version-specific mocking
2. **No External Dependencies**: Tests run without requiring a Redis server
3. **Fast Execution**: No network I/O, even to localhost
4. **Focus on Instrumentation**: This gem instruments Sidekiq metrics, it doesn't test Redis behavior
5. **Sidekiq 7+/8+ Compatibility**: The new `redis-client` gem and connection pooling in Sidekiq 7+/8+ don't work well with traditional Redis mocks like `mock_redis` or `fakeredis`

### What We Test

- ✅ Middleware correctly intercepts Sidekiq operations
- ✅ Metrics are sent to StatsD and DogStatsD with correct values
- ✅ Worker metrics are tracked and reported
- ✅ Queue statistics are gathered and reported
- ✅ Error handling works correctly

### What We Don't Test

- ❌ Actual Redis read/write operations
- ❌ Sidekiq's internal Redis data structures
- ❌ Network connectivity to Redis

This is appropriate because **we're testing instrumentation, not Sidekiq itself**.

## Running Tests

```bash
# Run all tests
bundle exec rake

# Run specific test file
bundle exec rspec spec/sidekiq-instrument/worker_spec.rb

# Run tests with coverage
bundle exec rspec
# Coverage report will be in coverage/index.html
```

## Testing with Different Sidekiq Versions

The test suite includes version detection and adapts behavior automatically:

```ruby
SIDEKIQ_VERSION = Gem::Version.new(Sidekiq::VERSION)
SIDEKIQ_7_OR_HIGHER = SIDEKIQ_VERSION >= Gem::Version.new('7.0.0')
```

To test against a specific Sidekiq version:

```bash
# Edit Gemfile.lock or use bundle update
bundle update sidekiq --conservative

# Or specify in Gemfile temporarily
gem 'sidekiq', '~> 6.5'
```

## CI Testing Matrix

GitHub Actions tests against:
- Ruby: 2.7.8, 3.0, 3.1, 3.2, 3.3
- Sidekiq: Latest compatible version for each Ruby version

## Alternative Testing Strategies

If you need to test actual Redis integration:

### 1. Use Real Redis in Tests

```ruby
# Requires Redis server running
system("redis-server --daemonize yes --port 6380")
ENV['REDIS_URL'] = 'redis://localhost:6380'
```

### 2. Use Testcontainers (for CI)

```ruby
gem 'testcontainers-redis'

RSpec.configure do |config|
  config.before(:suite) do
    @redis = Testcontainers::RedisContainer.new
    @redis.start
    ENV['REDIS_URL'] = @redis.connection_url
  end
end
```

### 3. Use Docker Compose

```yaml
# docker-compose.test.yml
version: '3'
services:
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
```

## Known Limitations

- `mock_redis` only supports the classic `redis` gem API (< 5.0)
- Tests don't verify actual Redis persistence
- Connection pool behavior in Sidekiq 7+/8+ is stubbed, not tested

These limitations are acceptable for an instrumentation gem that doesn't modify or depend on Sidekiq's Redis behavior.
