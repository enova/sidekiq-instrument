# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- **BREAKING**: Minimum Ruby version raised from 2.6 to 2.7.8
- Updated all gem dependencies to their latest compatible versions
- Removed upper version constraint on ActiveSupport dependency (was `< 7.2`, now `>= 5.1` with no upper limit)
- Removed upper version constraint on Sidekiq dependency (was `< 7`, now `>= 4.2` with no upper limit)
- Updated Bundler to version 4.0.1
- Migrated to Ruby 3.x modern syntax patterns (frozen_string_literal, **dir**)
- Updated test suite for Sidekiq 8.x API compatibility (Sidekiq.configure_server)

### Added

- Ruby 3.3 support and full compatibility
- CI testing for Ruby versions 2.7.8, 3.0, 3.1, 3.2, and 3.3
- Redis gem dependency (>= 4.0) for compatibility with worker metrics
- **Redis 8.x support** - CI now tests against Redis 4.0.14, 5.0.14, 6.2.14, 7.2.4, and 8.0.1
- **Valkey support** - Full compatibility with Valkey 7.2+ and 8.0+ as a Redis-compatible alternative
- CI testing matrix for Valkey versions 7.2.7 and 8.0.1
- Gemspec constraint: `required_ruby_version >= 2.7.8` to enforce minimum Ruby version at installation

### Upgraded

- Sidekiq: now supports 8.0.x (previously limited to < 7)
- ActiveSupport: now supports 8.x (previously limited to < 7.2)
- RSpec: 3.13.x
- Rubocop: 1.81.x
- Rake: 13.3.x
- dogstatsd-ruby: 5.7.x
- statsd-instrument: 3.9.x
- redis: 5.4.x
- redis-client: 0.26.x
- simplecov: 0.22.x

### Removed

- Ruby 2.6 support (end of life)
- Version constraints that prevented using latest gem versions
