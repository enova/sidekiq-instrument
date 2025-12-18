# Testing Strategy

## Overview

This gem supports Sidekiq versions 4.2 through 8.x, which span a major transition in Redis client libraries:
- **Sidekiq 4.x-6.x**: Uses `redis` gem 3.x-4.x with classic API
- **Sidekiq 7.x+**: Uses `redis` gem 5.x + `redis-client` gem with new connection pooling

## Testing Approach

### Automatic Redis Detection

The test suite **automatically detects** whether a real Redis server is available:

1. **Real Redis Available (CI and local with Redis)**: 
   - Uses actual Redis connection via `Sidekiq.configure_client/server`
   - Tests the **real** Sidekiq + Redis code paths
   - Verifies actual production behavior
   - All 48 tests pass ✅

2. **No Redis Available (local development)**: 
   - Falls back to `mock_redis` 
   - Stubs `Sidekiq::Stats`, `Sidekiq::Workers`, and `Sidekiq::Queue`
   - Tests still run, but with mocked Redis behavior
   - Some worker stats tests may fail (expected with mocks)

### Why This Hybrid Approach?

**Real Redis (preferred)**:
- ✅ Tests actual production code paths
- ✅ Verifies Sidekiq 4.2-8.x compatibility with real Redis
- ✅ CI always uses real Redis (via GitHub Actions)
- ✅ Catches real integration issues

**Mock Redis (fallback)**:
- ✅ Allows local development without Redis dependency
- ✅ Fast test execution
- ✅ Works across all Sidekiq versions
- ⚠️ Doesn't test actual Redis interactions
- ⚠️ Some tests may fail (mock limitations)

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

### With Real Redis (Recommended)

```bash
# Start Redis server (if not already running)
redis-server --daemonize yes

# Run tests - will automatically detect and use Redis
bundle exec rake

# Or run specific test file
bundle exec rspec spec/sidekiq-instrument/worker_spec.rb
```

### Without Redis (Mock Mode)

```bash
# Stop Redis if running
redis-cli shutdown

# Run tests - will automatically use mock_redis
bundle exec rake
```

### Force Real or Mock Redis

```bash
# Force real Redis (fails if Redis not available)
USE_REAL_REDIS=true bundle exec rspec

# Force mock Redis (even if Redis is available)
USE_REAL_REDIS=false bundle exec rspec
```

## Testing with Different Sidekiq Versions

The test suite automatically adapts to the installed Sidekiq version. To test against a specific Sidekiq version:

```bash
# Test with Sidekiq 6.x
echo "gem 'sidekiq', '~> 6.5'" > Gemfile.test
bundle install --gemfile=Gemfile.test
BUNDLE_GEMFILE=Gemfile.test bundle exec rspec

# Test with Sidekiq 7.x
echo "gem 'sidekiq', '~> 7.0'" > Gemfile.test  
bundle install --gemfile=Gemfile.test
BUNDLE_GEMFILE=Gemfile.test bundle exec rspec

# Test with Sidekiq 8.x (current)
bundle exec rspec
```

**Note**: Sidekiq 7.x+ requires a `Sidekiq[:key]` compatibility shim which is included in `spec_helper.rb`.

## CI Testing Matrix

GitHub Actions CI **always uses real Redis** and tests against:
- **Ruby versions**: 2.7.8, 3.0, 3.1, 3.2, 3.3
- **Redis versions**: 4, 5, 6, 7, 8
- **Sidekiq versions**: 4, 5, 6, 7, 8
- **Valkey** (Redis fork) versions: 7, 8

This comprehensive matrix ensures compatibility across all supported combinations. The CI workflow:
1. Starts a real Redis/Valkey server
2. Tests automatically detect and use the real Redis connection
3. All 48 tests must pass for each combination

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

### With Mock Redis
- Some `Sidekiq::Stats`, `Sidekiq::Workers`, and `Sidekiq::Queue` tests may fail
- Mock doesn't fully support `redis-client` API (Sidekiq 7+/8+)
- Worker metrics tests may not work correctly
- **Expected failures**: ~10 tests when using mocks

### With Real Redis
- Requires Redis server running (automatically detected)
- Tests modify Redis data (cleared before each test)
- **All 48 tests pass** ✅

These limitations only affect **test execution**, not the actual gem functionality in production.
