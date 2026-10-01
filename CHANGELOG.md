# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.4] - 2026-10-01

### Added
- Offline-first sync from db_dsl 0.2.4: tables declared with `syncWith`
  record every write as a change in the same commit as the row, and
  `db.sync` moves the changes to a server and its changes back (see db_dsl's
  PROTOCOL.md, "Sync"). The conformance suite runs its sync cases on this
  engine.

### Changed
- Native libraries of offline_first_core 0.7.5 and db_dsl `^0.2.4`.

## [0.3.3] - 2026-10-01

### Changed
- Native libraries of offline_first_core 0.7.4: an `eqAny` on the primary
  key or on the leading field of an index reads only the keys it names, so
  `belongingTo` and `Relation` read only the neighbours of a row.
- db_dsl `^0.2.3`: `Relation`, a many-to-many through a bridge table.

### Added
- A test that a relation's reads are an index range and primary key
  lookups on the native engine, never a full scan.

## [0.3.2] - 2026-10-01

Documentation, tests and a benchmark; no change in behaviour.

### Added
- `benchmark/`: dart_db against SQLite, Hive CE and Sembast in a
  `dart build cli` bundle, including lookups from 4 isolates at once; the
  results and how to read them are in the README.
- A test with three isolates writing the same database at once.

### Changed
- README: every isolate that uses the database gets a worker isolate of its
  own, and all of them share the process's one LMDB environment (it said
  one worker per process).

## [0.3.1] - 2026-10-01

Documentation; no change in behaviour.

### Changed
- README: "How it works" (the path of a query from a handler to LMDB, the
  bundled library in `dart run` and in a `dart build cli` bundle,
  concurrent handlers, a program that ends by itself) and "Using it well",
  with the Windows note on concurrent `dart run` (dart-lang/sdk#63933).
- 0.3.0 already keeps the bindings in ahead-of-time builds: the server
  bundle runs on Linux, macOS and Windows, checked in CI.

## [0.3.0] - 2026-10-01

A new database: tables from your own models with Diesel-style queries
([db_dsl](https://pub.dev/packages/db_dsl), re-exported), on
offline_first_core and LMDB 1.0.2. The files and the key-value API of 0.2
are not compatible: see "Migrating from 0.2" in the README.

### Added
- `DartDb.open(path)`: tables carried by the models themselves
  (`static final table = DbTable<Note>('notes', key: 'id', fromJson:
  Note.fromJson)`), defined on the database the first time they are used
  (`tables:` defines them up front), with secondary indexes, filters,
  ordering, limits, aggregates, `groupBy` with `having`, joins, transactions
  with savepoints, read snapshots, `atomicBatch`, `watch` and `explain`.
- Typed fields (`notes.author.eq('ada')`) through an
  `extension NoteFields on DbTable<Note>` that the
  [db_dsl_lints](https://pub.dev/packages/db_dsl_lints) analyzer plugin
  writes from the model and checks.
- Queries run when awaited, and every call answers a `Result` with a typed
  `DbError`.
- A build hook bundles the native library for Linux, macOS and Windows on
  x64 and arm64; `dart build cli` ships it next to the executable.
- `example/server.dart`: a small HTTP API on dart_db.
- `tool/update_native.sh`: replaces the bundled libraries with those of an
  offline_first_core release.

### Changed
- Every call runs on a database isolate, so request handlers never block on
  the disk; a program that closes its databases ends by itself.

### Removed
- The key-value `DB` class of 0.2 (`open`, `post`, `put`, `patch`, `get`,
  `delete`, `exists`, `keys`, `all`, `clear`), `DbResult` and `DbError` of
  0.2: tables and db_dsl's `Result` / `DbError` replace them.
- Support for files written by 0.2 (LMDB 0.9): opening them answers
  `DbErrorCode.legacyFormat`.

## [0.2.0] - 2025-08-27

### 🎉 Major Simplification & Server Focus

### Added
- **📦 Published on pub.dev** - Easy installation with `dart pub add dart_db`
- **🔧 Simplified JSON handling** - Direct `jsonEncode`/`jsonDecode` approach
- **📁 Simple path resolution** - Standard system conventions (no complex hardcoded paths)
- **🖥️ Server-first design** - Explicitly focused on server applications only
- **⚡ Improved performance** - Streamlined operations and reduced overhead

### Changed
- **BREAKING**: Simplified API focused on server use cases only
- **BREAKING**: Removed complex path resolution in favor of standard conventions
- **BREAKING**: Only functions that exist in Rust backend are exposed
- Streamlined JSON response parsing
- Updated documentation with server-focused examples
- Enhanced error messages for better debugging

### Removed
- **BREAKING**: Removed `stats()` method (not implemented in Rust backend)
- **BREAKING**: Removed mobile/Flutter compatibility (server-only now)
- Complex hardcoded path arrays
- Redundant JSON parsing layers

### Fixed
- Path resolution using proper `path` package conventions
- Corrected FFI bindings to match actual Rust function signatures
- Simplified database operations for better reliability
- Fixed `exists()`, `keys()`, and `all()` methods implementation

### Technical Improvements
- Direct `jsonEncode`/`jsonDecode` instead of complex parsing
- Simplified `ServerPathHelper` with standard path conventions
- Fallback implementations for optional Rust functions
- Better error handling for missing backend functions

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

[Unreleased]: https://github.com/JhonaCodes/dart_db/compare/v0.3.3...HEAD
[0.3.3]: https://github.com/JhonaCodes/dart_db/compare/v0.3.2...v0.3.3
[0.3.2]: https://github.com/JhonaCodes/dart_db/compare/v0.3.1...v0.3.2
[0.3.1]: https://github.com/JhonaCodes/dart_db/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/JhonaCodes/dart_db/releases/tag/v0.3.0
