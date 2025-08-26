# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial project setup and documentation

## [0.1.0] - 2025-01-26

### Added
- Initial release of DartDB
- High-performance embedded key-value database for pure Dart backend applications
- Built on LMDB (Lightning Memory-Mapped Database) with Rust FFI integration
- Core database operations:
  - `set(key, value)` - Store data with any JSON-serializable type
  - `get<T>(key)` - Retrieve data with optional type casting
  - `get<T>(key, defaultValue)` - Retrieve data with default fallback
  - `exists(key)` - Check if key exists
  - `delete(key)` - Remove data
  - `keys()` - Get all keys
  - `keys(pattern)` - Get keys matching pattern
- Batch operations:
  - `setMultiple(Map<String, dynamic>)` - Set multiple values at once
  - `getMultiple(List<String>)` - Get multiple values at once
  - `deleteMultiple(List<String>)` - Delete multiple keys at once
- Advanced operations:
  - `increment(key, by)` - Increment numeric values
  - `decrement(key, by)` - Decrement numeric values
  - `setWithTTL(key, value, duration)` - Set with expiration time
  - `stats()` - Get database statistics
- Transaction support:
  - `transaction((txn) async { ... })` - Execute write operations in transaction
  - `readTransaction((txn) async { ... })` - Execute read-only transaction
- Configurable database options:
  - Maximum database size configuration
  - Read-only mode support
  - Custom sync modes (full, lazy, none)
  - Compression settings with LZ4 algorithm
  - Maximum readers configuration
- Cross-platform support for Linux, macOS, and Windows
- ACID compliance with full transaction support
- Memory-efficient operation with memory-mapped files
- Redis-like API for familiar key-value operations
- Comprehensive error handling and type safety
- Built-in logging with configurable log levels
- Environment variable configuration support
- In-memory database option (`:memory:`) for testing
- Full JSON serialization support for complex Dart objects
- Performance optimizations:
  - Up to 1M+ read operations per second
  - Up to 100K+ write operations per second
  - Microsecond-level latency for basic operations
  - Efficient batch operations for bulk data handling
  - Low memory footprint with memory-mapped storage
- Complete test suite with comprehensive coverage
- Extensive documentation with practical examples:
  - Web API caching implementation
  - Session storage system
  - Configuration management
  - Troubleshooting guide
  - Performance benchmarks
- MIT License for open source usage
- Ready for pub.dev publication

### Technical Details
- Built with Dart SDK 3.0.0+ compatibility
- FFI integration with Rust for native performance
- LMDB engine for proven reliability and speed
- Memory-mapped file I/O for optimal performance
- Multi-reader, single-writer concurrency model
- Crash-safe operation with automatic recovery
- Flexible data serialization supporting all JSON-compatible types

### Use Cases
- Caching layer for backend applications
- Session storage with persistence
- Configuration and metadata storage
- Job queue and task scheduling
- Metrics collection and analytics
- Embedded analytics and data processing
- High-performance key-value operations in pure Dart environments

[Unreleased]: https://github.com/jhonacodes/dart_db/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/jhonacodes/dart_db/releases/tag/v0.1.0
