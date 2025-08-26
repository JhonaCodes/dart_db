// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║                              FFI BINDINGS                                    ║
// ║                    Foreign Function Interface for LMDB Backend               ║
// ║══════════════════════════════════════════════════════════════════════════════║
// ║                                                                              ║
// ║  Author: JhonaCode (Jhonatan Ortiz)                                         ║
// ║  Contact: info@jhonacode.com                                                 ║
// ║  Module: ffi_bindings.dart                                                   ║
// ║  Purpose: FFI type definitions and function signatures for Linux backend    ║
// ║                                                                              ║
// ║  Description:                                                                ║
// ║    Defines all FFI type definitions and function signatures for             ║
// ║    interfacing with the Rust LMDB backend on Linux servers.                ║
// ║    Optimized for backend applications and server environments.             ║
// ║                                                                              ║
// ║  Features:                                                                   ║
// ║    • Linux-optimized FFI bindings                                            ║
// ║    • Type-safe function signatures                                           ║
// ║    • Memory management helpers                                               ║
// ║    • Server-grade performance                                                ║
// ║                                                                              ║
// ╚══════════════════════════════════════════════════════════════════════════════╝

import 'dart:ffi';
import 'package:ffi/ffi.dart';

/// FFI type definitions for database operations

/// Initialize database with given path
typedef CreateDbNative = Pointer<Void> Function(Pointer<Utf8> path);
typedef CreateDb = Pointer<Void> Function(Pointer<Utf8> path);

/// Store key-value pair in database
typedef PutNative = Int32 Function(Pointer<Void> db, Pointer<Utf8> key, Pointer<Utf8> value);
typedef Put = int Function(Pointer<Void> db, Pointer<Utf8> key, Pointer<Utf8> value);

/// Retrieve value by key from database
typedef GetNative = Pointer<Utf8> Function(Pointer<Void> db, Pointer<Utf8> key);
typedef Get = Pointer<Utf8> Function(Pointer<Void> db, Pointer<Utf8> key);

/// Delete record by key from database
typedef DeleteNative = Int32 Function(Pointer<Void> db, Pointer<Utf8> key);
typedef Delete = int Function(Pointer<Void> db, Pointer<Utf8> key);

/// Check if key exists in database
typedef ExistsNative = Int32 Function(Pointer<Void> db, Pointer<Utf8> key);
typedef Exists = int Function(Pointer<Void> db, Pointer<Utf8> key);

/// Get all keys from database
typedef GetAllKeysNative = Pointer<Utf8> Function(Pointer<Void> db);
typedef GetAllKeys = Pointer<Utf8> Function(Pointer<Void> db);

/// Get all key-value pairs from database
typedef GetAllNative = Pointer<Utf8> Function(Pointer<Void> db);
typedef GetAll = Pointer<Utf8> Function(Pointer<Void> db);

/// Get database statistics
typedef GetStatsNative = Pointer<Utf8> Function(Pointer<Void> db);
typedef GetStats = Pointer<Utf8> Function(Pointer<Void> db);

/// Clear all data from database
typedef ClearNative = Int32 Function(Pointer<Void> db);
typedef Clear = int Function(Pointer<Void> db);

/// Close database and free resources
typedef CloseDbNative = Void Function(Pointer<Void> db);
typedef CloseDb = void Function(Pointer<Void> db);

/// Free string memory allocated by Rust
typedef FreeStringNative = Void Function(Pointer<Utf8> ptr);
typedef FreeString = void Function(Pointer<Utf8> ptr);

/// Container for all FFI function bindings
class DbBindings {
  final CreateDb createDb;
  final CloseDb closeDb;
  final Clear clear;
  final GetStats getStats;
  final Put post;  // post_data function
  final Put put;   // put_data function  
  final Get get;
  final Delete delete;
  final Exists exists;
  final GetAllKeys getAllKeys;
  final GetAll getAll;
  final FreeString freeString;
  
  const DbBindings({
    required this.createDb,
    required this.closeDb,
    required this.clear,
    required this.getStats,
    required this.post,
    required this.put,
    required this.get,
    required this.delete,
    required this.exists,
    required this.getAllKeys,
    required this.getAll,
    required this.freeString,
  });
  
  /// Creates bindings from the Linux shared library
  /// 
  /// Looks up all required functions and creates type-safe Dart bindings.
  /// 
  /// Example:
  /// ```dart
  /// final lib = DynamicLibrary.open('./liboffline_first_core.so');
  /// final bindings = DbBindings.fromLibrary(lib);
  /// ```
  factory DbBindings.fromLibrary(DynamicLibrary lib) {
    // Try to lookup functions, use default implementations if not found
    
    // Required functions
    final createDb = lib.lookupFunction<CreateDbNative, CreateDb>('create_db');
    final closeDb = lib.lookupFunction<CloseDbNative, CloseDb>('close_database');
    final clear = lib.lookupFunction<ClearNative, Clear>('clear_all_records');
    final post = lib.lookupFunction<PutNative, Put>('post_data');
    final put = lib.lookupFunction<PutNative, Put>('put_data');
    final get = lib.lookupFunction<GetNative, Get>('get_by_id');
    final delete = lib.lookupFunction<DeleteNative, Delete>('delete_by_id');
    final getAll = lib.lookupFunction<GetAllNative, GetAll>('get_all');
    
    // Optional functions with fallbacks
    GetStats? getStats;
    Exists? exists;
    GetAllKeys? getAllKeys;
    FreeString? freeString;
    
    try {
      getStats = lib.lookupFunction<GetStatsNative, GetStats>('get_stats');
    } catch (e) {
      // Use dummy implementation
      getStats = (Pointer<Void> db) => nullptr;
    }
    
    try {
      exists = lib.lookupFunction<ExistsNative, Exists>('exists');
    } catch (e) {
      // Use get-based implementation
      exists = (Pointer<Void> db, Pointer<Utf8> key) {
        final result = get(db, key);
        return result != nullptr ? 1 : 0;
      };
    }
    
    try {
      getAllKeys = lib.lookupFunction<GetAllKeysNative, GetAllKeys>('get_all_keys');
    } catch (e) {
      // Use dummy implementation
      getAllKeys = (Pointer<Void> db) => nullptr;
    }
    
    try {
      freeString = lib.lookupFunction<FreeStringNative, FreeString>('free_string');
    } catch (e) {
      // Use Dart's malloc.free
      freeString = (Pointer<Utf8> ptr) {
        // Note: This may cause issues if the string was allocated by Rust
        // but should work for basic cases
      };
    }
    
    return DbBindings(
      createDb: createDb,
      closeDb: closeDb,
      clear: clear,
      getStats: getStats,
      post: post,
      put: put,
      get: get,
      delete: delete,
      exists: exists,
      getAllKeys: getAllKeys,
      getAll: getAll,
      freeString: freeString,
    );
  }
}

/// Utility functions for FFI memory management
class FfiUtils {
  /// Converts a Dart string to a UTF-8 pointer
  static Pointer<Utf8> toCString(String str) => str.toNativeUtf8();
  
  /// Converts a UTF-8 pointer to a Dart string
  static String? fromCString(Pointer<Utf8> ptr) {
    if (ptr == nullptr) return null;
    return ptr.toDartString();
  }
  
  /// Frees a Dart-allocated UTF-8 string
  static void freeDartString(Pointer<Utf8> ptr) {
    if (ptr != nullptr) malloc.free(ptr);
  }
  
  /// Frees a Rust-allocated UTF-8 string
  static void freeRustString(Pointer<Utf8> ptr, DbBindings bindings) {
    if (ptr != nullptr) bindings.freeString(ptr);
  }
  
  /// Checks if a pointer is null
  static bool isNull(Pointer ptr) => ptr == nullptr;
  
  /// Checks if a pointer is not null
  static bool isNotNull(Pointer ptr) => ptr != nullptr;
}

/// Constants for FFI operations
class FfiConstants {
  /// Success return code from native functions
  static const int success = 1;
  
  /// Failure return code from native functions
  static const int failure = 0;
  
  /// Maximum key length in bytes
  static const int maxKeyLength = 511;
  
  /// Maximum value size in bytes (16MB)
  static const int maxValueSize = 16 * 1024 * 1024;
}