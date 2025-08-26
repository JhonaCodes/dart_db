// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║                              DART DB                                         ║
// ║              High-Performance Embedded Database for Dart Backend             ║
// ║══════════════════════════════════════════════════════════════════════════════║
// ║                                                                              ║
// ║  Author: JhonaCode (Jhonatan Ortiz)                                         ║
// ║  Contact: info@jhonacode.com                                                 ║
// ║  Purpose: Pure Dart embedded database for backend applications              ║
// ║                                                                              ║
// ║  Description:                                                                ║
// ║    A high-performance embedded key-value database built specifically        ║
// ║    for Dart backend applications. Uses LMDB + Rust via FFI for blazing     ║
// ║    fast performance while maintaining a clean, simple Dart API.            ║
// ║                                                                              ║
// ║  Features:                                                                   ║
// ║    • Instance-based API (no singletons)                                     ║
// ║    • Type-safe operations with Result<T,E>                                  ║
// ║    • Linux-optimized for server environments                                ║
// ║    • Perfect for caches, sessions, config, and more                        ║
// ║                                                                              ║
// ╚══════════════════════════════════════════════════════════════════════════════╝

library dart_db;

// Core API
export 'src/db.dart';

// Models
export 'src/models/db_result.dart';
export 'src/models/db_error.dart';

// Utilities
export 'src/utils/server_path_helper.dart';
