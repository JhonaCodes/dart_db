# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **🔍 Automatic library detection via `package_config.json`**: Zero-configuration setup - the library loader now automatically reads `.dart_tool/package_config.json` to find the exact location of the dart_db package
- **📊 Comprehensive logging**: Added detailed logging throughout the library loading process using `Log.d()`, `Log.i()`, `Log.w()`, and `Log.e()` for better debugging visibility
- **🛠️ Diagnostic tool (`LibraryLoader.printDebugInfo()`)**: New debugging utility that provides detailed information about library search paths, system configuration, and actionable troubleshooting recommendations
- **📋 Debug example (`example/debug.dart`)**: Interactive diagnostic tool that helps users troubleshoot library loading issues
- **🩺 Linux diagnostic script (`scripts/diagnose_linux.sh`)**: Comprehensive shell script that checks file permissions, verifies dependencies with `ldd`, tests library loading, and provides platform-specific fix commands
- **⚙️ Installation script (`scripts/install_linux.sh`)**: Automated installer for manual system-level installation as a fallback option
- **📚 Comprehensive troubleshooting guide (`TROUBLESHOOTING.md`)**: Detailed documentation covering library loading issues and solutions

### Changed
- **Enhanced library search algorithm**: Now prioritizes `package_config.json` for the most reliable package location detection
- **Improved error messages**: Library loading errors now include:
  - The actual error from `DynamicLibrary.open()` for better debugging
  - Helpful context-aware suggestions based on whether file exists but can't load vs. file not found
  - Direct links to diagnostic tools and documentation
  - Step-by-step troubleshooting commands
- **Better search coverage**: Enhanced search paths to support git repositories, pub.dev hosted packages, and local development paths
- **Verbose logging**: All library loading steps are now logged to help identify issues in real-time
- **README updated**: Added section on automatic library detection, diagnostic tools, and quick fixes

### Fixed
- **Library loading on Linux servers**: Automatic detection now correctly resolves the package root path from `package_config.json`, handling both absolute and relative URI formats
- **Package path resolution**: Fixed issue where library couldn't be found when dart_db was used as a dependency in other projects
- **Support for various installation methods**: Now correctly handles packages installed via git, pub.dev, and local paths
- **Error diagnosis**: Now captures and displays the actual loading error instead of silently continuing, making it easier to identify missing dependencies or permission issues

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

[Unreleased]: https://github.com/jhonacodes/dart_db/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/jhonacodes/dart_db/releases/tag/v0.1.0
