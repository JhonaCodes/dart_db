// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║                                  DB                                          ║
// ║                  High-Performance Embedded Database for Dart                 ║
// ║══════════════════════════════════════════════════════════════════════════════║
// ║                                                                              ║
// ║  Author: JhonaCode (Jhonatan Ortiz)                                         ║
// ║  Contact: info@jhonacode.com                                                 ║
// ║  Module: db.dart                                                             ║
// ║  Purpose: Main database class with instance-based API                       ║
// ║                                                                              ║
// ║  Description:                                                                ║
// ║    Provides a clean, instance-based API for embedded database operations   ║
// ║    Perfect for backend applications, APIs, and server-side Dart apps.      ║
// ║    No singletons, no static methods - just clean, predictable instances.   ║
// ║                                                                              ║
// ║  Features:                                                                   ║
// ║    • Instance-based API (no singletons)                                     ║
// ║    • Type-safe operations                                                    ║
// ║    • High-performance LMDB backend                                           ║
// ║    • Perfect for backend services                                            ║
// ║                                                                              ║
// ╚══════════════════════════════════════════════════════════════════════════════╝

import 'dart:ffi';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:logger_rs/logger_rs.dart';
import 'core/ffi_bindings.dart';
import 'core/library_loader.dart';
import 'models/db_result.dart';
import 'models/db_error.dart';
import 'utils/server_path_helper.dart';

/// High-performance embedded database for Dart backend applications
///
/// Provides a clean, instance-based API for embedded key-value storage.
/// Perfect for backend services, APIs, caches, and server applications.
///
/// Example usage:
/// ```dart
/// // Open a database
/// final result = DB.open('user_sessions');
/// if (result.isErr) {
///   print('Failed to open database: ${result.errOrNull}');
///   return;
/// }
///
/// final db = result.okOrNull!;
///
/// // Store data
/// await db.post('session_123', {
///   'userId': 'user_456',
///   'createdAt': DateTime.now().toIso8601String(),
///   'data': {'theme': 'dark', 'lang': 'en'},
/// });
///
/// // Retrieve data
/// final userData = await db.get('session_123');
/// userData.when(
///   ok: (data) => print('User data: $data'),
///   err: (error) => print('Not found: $error'),
/// );
///
/// // Clean up
/// db.close();
/// ```
class DB {
  final String _name;
  final DbBindings _bindings;
  final Pointer<Void> _handle;
  bool _closed = false;

  /// Private constructor - use [DB.open] to create instances
  DB._(this._name, this._bindings, this._handle);

  /// Opens a database with the specified name
  ///
  /// Creates or opens a database file with the given name. The database
  /// will be stored in an appropriate server directory unless an absolute
  /// path is provided. For server applications, this automatically manages
  /// directory creation and path resolution.
  ///
  /// Parameters:
  /// - [name] - Database name or path (e.g., 'users', 'cache.lmdb', '/absolute/path/db.lmdb')
  ///
  /// Returns:
  /// - [Ok] with [DB] instance on success
  /// - [Err] with detailed error information on failure
  ///
  /// Example:
  /// ```dart
  /// final db = DB.open('user_cache').unwrap();  // Auto-managed path
  /// final analyticsDb = DB.open('analytics.lmdb').unwrap();  // Custom filename
  /// final customDb = DB.open('/tmp/custom.lmdb').unwrap();  // Absolute path
  /// ```
  static DbResult<DB, DbError> open(String name) {
    if (name.isEmpty) {
      return Err(DbError.validation('Database name cannot be empty'));
    }

    // Resolve database path using ServerPathHelper
    final pathResult = _resolveDatabasePath(name);
    if (pathResult.isErr) {
      return Err(pathResult.errOrNull!);
    }

    final dbPath = pathResult.okOrNull!;

    // Ensure directory exists
    final dirResult = ServerPathHelper.ensureDirectoryExists(dbPath);
    if (dirResult.isErr) {
      return Err(dirResult.errOrNull!);
    }

    // Load the native library
    final libraryResult = LibraryLoader.loadLibrary();
    if (libraryResult.isErr) {
      return Err(libraryResult.errOrNull!);
    }

    final library = libraryResult.okOrNull!;

    // Validate library functions
    final validationResult = LibraryLoader.validateLibrary(library);
    if (validationResult.isErr) {
      return Err(validationResult.errOrNull!);
    }

    // Create FFI bindings
    final bindings = DbBindings.fromLibrary(library);

    // Create database handle with resolved path
    final namePtr = FfiUtils.toCString(dbPath);

    try {
      final handle = bindings.createDb(namePtr);

      if (FfiUtils.isNull(handle)) {
        return Err(DbError.initialization(
          'Failed to create database',
          context: dbPath,
        ));
      }

      return Ok(DB._(name, bindings, handle));
    } catch (e, stackTrace) {
      return Err(DbError.initialization(
        'Exception during database creation',
        context: dbPath,
        cause: e,
        stackTrace: stackTrace,
      ));
    } finally {
      FfiUtils.freeDartString(namePtr);
    }
  }

  /// Stores data with the specified key (creates or updates)
  ///
  /// Stores JSON-serializable data with the given key. If the key already
  /// exists, the data will be updated. This is equivalent to an "upsert" operation.
  ///
  /// Parameters:
  /// - [key] - Unique identifier for the data
  /// - [data] - JSON-serializable data to store
  ///
  /// Returns:
  /// - [Ok] with the stored data on success
  /// - [Err] with detailed error information on failure
  ///
  /// Example:
  /// ```dart
  /// final result = db.post('user_123', {
  ///   'name': 'John Doe',
  ///   'email': 'john@example.com',
  ///   'settings': {'theme': 'dark'},
  /// });
  /// ```
  DbResult<Map<String, dynamic>, DbError> post(
      String key, Map<String, dynamic> data) {
    if (_closed) {
      return Err(DbError.database('Database is closed'));
    }

    final validation = _validateKeyAndData(key, data);
    if (validation.isErr) {
      return Err(validation.errOrNull!);
    }

    // Create the LocalDbModel format that Rust expects
    final localDbModel = {
      'id': key,
      'hash': _generateHash(key, data),
      'data': data,
    };

    final jsonString = jsonEncode(localDbModel);
    final jsonPtr = FfiUtils.toCString(jsonString);

    try {
      // Rust post_data expects only one parameter: the LocalDbModel JSON
      final resultPtr = _bindings.post(_handle, jsonPtr);
      Log.d(
          'DEBUG: post_data returned pointer: $resultPtr (null=${resultPtr == nullptr})');
      Log.d('DEBUG: key=$key, localDbModel=$localDbModel');

      if (!FfiUtils.isNull(resultPtr)) {
        FfiUtils.freeRustString(resultPtr, _bindings);

        // Simple success - return the original data since it was stored successfully
        return Ok(data);
      } else {
        return Err(DbError.database(
          'Failed to store data - Rust returned null pointer',
          context: key,
        ));
      }
    } catch (e, stackTrace) {
      return Err(DbError.database(
        'Exception during post operation',
        context: key,
        cause: e,
        stackTrace: stackTrace,
      ));
    } finally {
      FfiUtils.freeDartString(jsonPtr);
    }
  }

  /// Updates existing data (alias for post for API consistency)
  ///
  /// This is an alias for [post] to provide familiar CRUD naming.
  /// Behaves exactly the same as [post].
  ///
  /// Parameters:
  /// - [key] - Key to update
  /// - [data] - New data to store
  ///
  /// Returns:
  /// - [Ok] with the stored data on success
  /// - [Err] with detailed error information on failure
  DbResult<Map<String, dynamic>, DbError> put(
      String key, Map<String, dynamic> data) {
    return post(key, data);
  }

  /// Partially updates existing data (merges with existing data)
  ///
  /// Updates only the specified fields in an existing record, leaving other
  /// fields unchanged. If the key doesn't exist, this operation will fail.
  ///
  /// Parameters:
  /// - [key] - Key to update
  /// - [data] - Partial data to merge with existing data
  ///
  /// Returns:
  /// - [Ok] with the merged data on success
  /// - [Err] with detailed error information on failure
  ///
  /// Example:
  /// ```dart
  /// // First, store a user
  /// db.post('user_123', {'name': 'John', 'age': 30, 'city': 'NY'});
  ///
  /// // Then update only age and city
  /// final result = db.patch('user_123', {'age': 31, 'city': 'LA'});
  /// // Result: {'name': 'John', 'age': 31, 'city': 'LA'}
  /// ```
  DbResult<Map<String, dynamic>, DbError> patch(
      String key, Map<String, dynamic> data) {
    if (_closed) {
      return Err(DbError.database('Database is closed'));
    }

    // First, get existing data
    final existingResult = get(key);
    if (existingResult.isErr) {
      return Err(existingResult.errOrNull!);
    }

    final existingData = existingResult.okOrNull!;

    // Merge with new data (new data overwrites existing fields)
    final mergedData = Map<String, dynamic>.from(existingData);
    mergedData.addAll(data);

    // Store the merged data
    return post(key, mergedData);
  }

  /// Retrieves data by key
  ///
  /// Gets the data associated with the specified key from the database.
  ///
  /// Parameters:
  /// - [key] - The key to retrieve
  ///
  /// Returns:
  /// - [Ok] with data map if the key exists
  /// - [Err] with not found error if the key doesn't exist
  /// - [Err] with other error types for various failures
  ///
  /// Example:
  /// ```dart
  /// final result = db.get('user_123');
  /// result.when(
  ///   ok: (data) => print('Name: ${data['name']}'),
  ///   err: (error) => print('Not found or error: $error'),
  /// );
  /// ```
  DbResult<Map<String, dynamic>, DbError> get(String key) {
    if (_closed) {
      return Err(DbError.database('Database is closed'));
    }

    final validation = _validateKey(key);
    if (validation.isErr) {
      return Err(validation.errOrNull!);
    }

    final keyPtr = FfiUtils.toCString(key);

    try {
      Log.d('DEBUG: get() - calling _bindings.get() for key: $key');
      final resultPtr = _bindings.get(_handle, keyPtr);
      Log.d(
          'DEBUG: get() - get_by_id returned pointer: $resultPtr (null=${resultPtr == nullptr})');

      if (FfiUtils.isNull(resultPtr)) {
        Log.d('DEBUG: get() - pointer is null, returning not found');
        return Err(DbError.notFound('Key not found', context: key));
      }

      final jsonString = FfiUtils.fromCString(resultPtr);
      Log.d('DEBUG: get() - extracted JSON string: "$jsonString"');
      FfiUtils.freeRustString(resultPtr, _bindings);

      if (jsonString == null) {
        Log.d('DEBUG: get() - JSON string is null after conversion');
        return Err(DbError.serialization(
          'Received null JSON string',
          context: key,
        ));
      }

      // Simple JSON parsing - just decode and return
      try {
        final response = jsonDecode(jsonString);

        if (response is Map<String, dynamic>) {
          // Handle Rust AppResponse format
          if (response.containsKey('Ok')) {
            final innerData = response['Ok'];
            if (innerData is String) {
              final localDbModel =
                  jsonDecode(innerData) as Map<String, dynamic>;
              return Ok(localDbModel['data'] ?? <String, dynamic>{});
            }
            return Ok(innerData is Map<String, dynamic>
                ? innerData
                : <String, dynamic>{});
          }

          // Handle error responses
          if (response.containsKey('NotFound')) {
            return Err(DbError.notFound('Key not found', context: key));
          }

          // Direct data response
          return Ok(response);
        }

        return Err(DbError.serialization('Invalid response format'));
      } catch (e) {
        return Err(DbError.serialization('Failed to parse JSON', cause: e));
      }
    } catch (e, stackTrace) {
      Log.d('DEBUG: get() - exception occurred: $e');
      return Err(DbError.database(
        'Exception during get operation',
        context: key,
        cause: e,
        stackTrace: stackTrace,
      ));
    } finally {
      FfiUtils.freeDartString(keyPtr);
    }
  }

  /// Deletes data by key
  ///
  /// Removes the data associated with the specified key from the database.
  /// Returns success even if the key doesn't exist.
  ///
  /// Parameters:
  /// - [key] - The key to delete
  ///
  /// Returns:
  /// - [Ok] with void on successful deletion
  /// - [Err] with detailed error information on failure
  ///
  /// Example:
  /// ```dart
  /// final result = db.delete('old_session');
  /// result.when(
  ///   ok: (_) => print('Deleted successfully'),
  ///   err: (error) => print('Delete failed: $error'),
  /// );
  /// ```
  DbResult<bool, DbError> delete(String key) {
    if (_closed) {
      return Err(DbError.database('Database is closed'));
    }

    final validation = _validateKey(key);
    if (validation.isErr) {
      return Err(validation.errOrNull!);
    }

    final keyPtr = FfiUtils.toCString(key);

    try {
      final result = _bindings.delete(_handle, keyPtr);

      if (result == nullptr) {
        return Err(DbError.database(
          'Failed to delete data - null response',
          context: key,
        ));
      }

      final responseStr = FfiUtils.fromCString(result);
      FfiUtils.freeRustString(result, _bindings);

      if (responseStr == null) {
        return Err(DbError.database(
          'Failed to delete data - invalid response',
          context: key,
        ));
      }

      try {
        final responseJson = jsonDecode(responseStr);

        if (responseJson is Map<String, dynamic> &&
            responseJson['success'] == true) {
          return const Ok(true);
        } else {
          final message = responseJson['message'] ?? 'Delete operation failed';
          return Err(DbError.database(
            message,
            context: key,
          ));
        }
      } catch (jsonError) {
        return Err(DbError.database(
          'Failed to parse delete response',
          context: key,
          cause: jsonError,
        ));
      }
    } catch (e, stackTrace) {
      return Err(DbError.database(
        'Exception during delete operation',
        context: key,
        cause: e,
        stackTrace: stackTrace,
      ));
    } finally {
      FfiUtils.freeDartString(keyPtr);
    }
  }

  /// Checks if a key exists in the database
  ///
  /// Performs a fast existence check without retrieving the actual data.
  ///
  /// Parameters:
  /// - [key] - The key to check
  ///
  /// Returns:
  /// - [Ok] with true if the key exists, false otherwise
  /// - [Err] with detailed error information on failure
  ///
  /// Example:
  /// ```dart
  /// final result = db.exists('user_123');
  /// result.when(
  ///   ok: (exists) => print('Key exists: $exists'),
  ///   err: (error) => print('Check failed: $error'),
  /// );
  /// ```
  DbResult<bool, DbError> exists(String key) {
    if (_closed) {
      return Err(DbError.database('Database is closed'));
    }

    final validation = _validateKey(key);
    if (validation.isErr) {
      return Err(validation.errOrNull!);
    }

    // Simple approach: try to get the key, if it works then it exists
    final getResult = get(key);
    return Ok(getResult.isOk);
  }

  /// Gets all keys from the database
  ///
  /// Uses fallback to extract keys from all() method since get_all_keys
  /// may not be implemented in Rust backend.
  DbResult<List<String>, DbError> keys() {
    if (_closed) {
      return Err(DbError.database('Database is closed'));
    }

    // Use all() method and extract keys as fallback
    final allResult = all();
    return allResult.when(
      ok: (allData) => Ok(allData.keys.toList()),
      err: (error) => Err(error),
    );
  }

  /// Gets all key-value pairs from the database
  ///
  /// Returns a map containing all data currently stored in the database.
  ///
  /// Returns:
  /// - [Ok] with map of all key-value pairs
  /// - [Err] with detailed error information on failure
  ///
  /// Example:
  /// ```dart
  /// final result = db.all();
  /// result.when(
  ///   ok: (allData) => {
  ///     print('Found ${allData.length} records'),
  ///     allData.forEach((key, data) => print('$key: $data')),
  ///   },
  ///   err: (error) => print('Failed: $error'),
  /// );
  /// ```
  DbResult<Map<String, Map<String, dynamic>>, DbError> all() {
    if (_closed) {
      return Err(DbError.database('Database is closed'));
    }

    try {
      Log.d('DEBUG: all() - calling _bindings.getAll()');
      final resultPtr = _bindings.getAll(_handle);
      Log.d(
          'DEBUG: all() - getAll returned pointer: $resultPtr (null=${resultPtr == nullptr})');

      if (FfiUtils.isNull(resultPtr)) {
        Log.d('DEBUG: all() - pointer is null, returning empty map');
        return const Ok({});
      }

      final jsonString = FfiUtils.fromCString(resultPtr);
      Log.d('DEBUG: all() - extracted JSON string: "$jsonString"');
      FfiUtils.freeRustString(resultPtr, _bindings);

      if (jsonString == null) {
        Log.d('DEBUG: all() - JSON string is null after conversion');
        return Err(DbError.serialization('Received null JSON for all data'));
      }

      try {
        Log.d('DEBUG: all() - attempting to decode JSON response');
        final response = jsonDecode(jsonString);

        if (response is Map<String, dynamic>) {
          // Handle Rust AppResponse format
          if (response.containsKey('Ok')) {
            final allData = response['Ok'];

            if (allData is String) {
              // If it's a JSON string, decode it
              final innerData = jsonDecode(allData);

              if (innerData is List) {
                // Convert list of LocalDbModel objects to map
                final result = <String, Map<String, dynamic>>{};

                for (final item in innerData) {
                  if (item is Map<String, dynamic> &&
                      item.containsKey('id') &&
                      item.containsKey('data')) {
                    final id = item['id'] as String;
                    final data = item['data'] as Map<String, dynamic>;
                    result[id] = data;
                  }
                }

                print(
                    'DEBUG: all() - successfully decoded ${result.length} records');
                return Ok(result);
              }
            }
          }
        }

        return Err(DbError.serialization('Invalid all() response format'));
      } catch (e) {
        Log.d('DEBUG: all() - failed to decode JSON: $e');
        return Err(
            DbError.serialization('Failed to decode all data JSON', cause: e));
      }
    } catch (e, stackTrace) {
      Log.d('DEBUG: all() - exception occurred: $e');
      return Err(DbError.database(
        'Exception during all operation',
        cause: e,
        stackTrace: stackTrace,
      ));
    }
  }

  /// Clears all data from the database
  ///
  /// Removes all records from the database. This operation cannot be undone.
  /// Use with caution!
  ///
  /// Returns:
  /// - [Ok] with void on successful clear
  /// - [Err] with detailed error information on failure
  ///
  /// Example:
  /// ```dart
  /// final result = db.clear();
  /// result.when(
  ///   ok: (_) => print('Database cleared'),
  ///   err: (error) => print('Clear failed: $error'),
  /// );
  /// ```
  DbResult<bool, DbError> clear() {
    if (_closed) {
      return Err(DbError.database('Database is closed'));
    }

    try {
      final result = _bindings.clear(_handle);

      if (result == nullptr) {
        return Err(
            DbError.database('Failed to clear database - null response'));
      }

      final responseStr = FfiUtils.fromCString(result);
      FfiUtils.freeRustString(result, _bindings);

      if (responseStr == null) {
        return Err(
            DbError.database('Failed to clear database - invalid response'));
      }

      try {
        final responseJson = jsonDecode(responseStr);

        if (responseJson is Map<String, dynamic> &&
            responseJson['success'] == true) {
          return const Ok(true);
        } else {
          final message = responseJson['message'] ?? 'Clear operation failed';
          return Err(DbError.database(message));
        }
      } catch (jsonError) {
        return Err(DbError.database(
          'Failed to parse clear response',
          cause: jsonError,
        ));
      }
    } catch (e, stackTrace) {
      return Err(DbError.database(
        'Exception during clear operation',
        cause: e,
        stackTrace: stackTrace,
      ));
    }
  }

  /// Closes the database and releases resources
  ///
  /// Properly closes the database connection and releases all associated
  /// resources. After calling this method, the database instance cannot be used.
  ///
  /// Example:
  /// ```dart
  /// db.close();
  /// print('Database closed');
  /// ```
  void close() {
    if (_closed) return;

    try {
      _bindings.closeDb(_handle);
      _closed = true;
    } catch (e) {
      // Log error but don't throw
    }
  }

  /// Gets the database name
  String get name => _name;

  /// Checks if the database is closed
  bool get isClosed => _closed;

  // Private helper methods

  /// Validates a key for database operations
  DbResult<void, DbError> _validateKey(String key) {
    if (key.isEmpty) {
      return Err(DbError.validation('Key cannot be empty'));
    }

    if (key.length > FfiConstants.maxKeyLength) {
      return Err(DbError.validation(
        'Key exceeds maximum length (${FfiConstants.maxKeyLength} bytes)',
        context: key,
      ));
    }

    return const Ok(null);
  }

  /// Validates key and data for storage operations
  DbResult<void, DbError> _validateKeyAndData(
    String key,
    Map<String, dynamic> data,
  ) {
    final keyValidation = _validateKey(key);
    if (keyValidation.isErr) {
      return keyValidation;
    }

    try {
      final jsonString = jsonEncode(data);
      if (jsonString.length > FfiConstants.maxValueSize) {
        return Err(DbError.validation(
          'Data exceeds maximum size (${FfiConstants.maxValueSize} bytes)',
          context: 'key: $key, size: ${jsonString.length}',
        ));
      }
    } catch (e) {
      return Err(DbError.validation(
        'Data is not JSON serializable',
        context: key,
        cause: e,
      ));
    }

    return const Ok(null);
  }

  /// Generates a hash for the LocalDbModel
  String _generateHash(String key, Map<String, dynamic> data) {
    final content = '$key:${jsonEncode(data)}';
    return content.hashCode.abs().toString();
  }

  /// Resolves database path from name using ServerPathHelper
  static DbResult<String, DbError> _resolveDatabasePath(String name) {
    try {
      // If already an absolute path, use it directly
      if (name.startsWith('/') ||
          name.startsWith('\\') ||
          (name.length > 1 && name[1] == ':')) {
        return Ok(name);
      }

      // Get the default database directory
      final defaultPath = ServerPathHelper.getDefaultDatabasePath();
      if (defaultPath.isErr) {
        return Err(defaultPath.errOrNull!);
      }

      final defaultDir = path.dirname(defaultPath.okOrNull!);

      // If it looks like a filename (has extension), use it directly
      if (name.contains('.')) {
        final customPath = path.join(defaultDir, name);
        return Ok(customPath);
      }

      // Otherwise, create a database name with .lmdb extension
      final dbName = name.endsWith('.lmdb') ? name : '$name.lmdb';
      final customPath = path.join(defaultDir, dbName);
      return Ok(customPath);
    } catch (e) {
      return Err(DbError.platform('Failed to resolve database path', cause: e));
    }
  }
}
