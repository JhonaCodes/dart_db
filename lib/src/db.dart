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
  DbResult<Map<String, dynamic>, DbError> post(String key, Map<String, dynamic> data) {
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
      print('DEBUG: post_data returned pointer: $resultPtr (null=${resultPtr == nullptr})');
      print('DEBUG: key=$key, localDbModel=$localDbModel');
      
      if (!FfiUtils.isNull(resultPtr)) {
        // Rust returns the stored model as JSON, parse it to extract the data
        final responseJson = FfiUtils.fromCString(resultPtr);
        FfiUtils.freeRustString(resultPtr, _bindings);
        
        if (responseJson != null) {
          print('DEBUG: post_data response: $responseJson');
          // Try to parse the response to get the stored model
          try {
            final parsedResponse = jsonDecode(responseJson) as Map<String, dynamic>;
            
            // Check if it's wrapped in AppResponse::Ok
            if (parsedResponse.containsKey('Ok')) {
              final innerJson = parsedResponse['Ok'] as String;
              final localDbModel = jsonDecode(innerJson) as Map<String, dynamic>;
              
              // Extract the 'data' field from LocalDbModel
              if (localDbModel.containsKey('data')) {
                final dataField = localDbModel['data'];
                if (dataField is Map<String, dynamic>) {
                  return Ok(dataField);
                }
              }
            }
            
            return Ok(data);
          } catch (e) {
            print('DEBUG: Failed to parse response JSON: $e');
            return Ok(data);
          }
        }
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
  DbResult<Map<String, dynamic>, DbError> put(String key, Map<String, dynamic> data) {
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
  DbResult<Map<String, dynamic>, DbError> patch(String key, Map<String, dynamic> data) {
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
      print('DEBUG: get() - calling _bindings.get() for key: $key');
      final resultPtr = _bindings.get(_handle, keyPtr);
      print('DEBUG: get() - get_by_id returned pointer: $resultPtr (null=${resultPtr == nullptr})');
      
      if (FfiUtils.isNull(resultPtr)) {
        print('DEBUG: get() - pointer is null, returning not found');
        return Err(DbError.notFound('Key not found', context: key));
      }
      
      final jsonString = FfiUtils.fromCString(resultPtr);
      print('DEBUG: get() - extracted JSON string: "$jsonString"');
      FfiUtils.freeRustString(resultPtr, _bindings);
      
      if (jsonString == null) {
        print('DEBUG: get() - JSON string is null after conversion');
        return Err(DbError.serialization(
          'Received null JSON string',
          context: key,
        ));
      }
      
      print('DEBUG: get() - attempting to deserialize JSON: "$jsonString"');
      
      // Parse the Rust response - it's wrapped in AppResponse format
      try {
        final parsedResponse = jsonDecode(jsonString) as Map<String, dynamic>;
        
        // Check if it's a successful response wrapped in AppResponse::Ok
        if (parsedResponse.containsKey('Ok')) {
          final innerJson = parsedResponse['Ok'] as String;
          final localDbModel = jsonDecode(innerJson) as Map<String, dynamic>;
          
          // Extract the 'data' field from LocalDbModel
          if (localDbModel.containsKey('data')) {
            final dataField = localDbModel['data'];
            if (dataField is Map<String, dynamic>) {
              return Ok(dataField);
            }
          }
        }
        
        // Check if it's an error response
        if (parsedResponse.containsKey('NotFound')) {
          return Err(DbError.notFound('Key not found', context: key));
        }
        
        // Check other error types
        if (parsedResponse.containsKey('BadRequest')) {
          return Err(DbError.validation(parsedResponse['BadRequest'] as String, context: key));
        }
        
        if (parsedResponse.containsKey('SerializationError')) {
          return Err(DbError.serialization(parsedResponse['SerializationError'] as String, context: key));
        }
        
        // Fallback: return the parsed response as-is
        return Ok(parsedResponse);
        
      } catch (e) {
        return Err(DbError.serialization(
          'Failed to parse response JSON',
          context: jsonString,
          cause: e,
        ));
      }
      
    } catch (e, stackTrace) {
      print('DEBUG: get() - exception occurred: $e');
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
      
      if (result == FfiConstants.success) {
        return const Ok(true);
      } else {
        return Err(DbError.database(
          'Failed to delete data',
          context: key,
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
    
    final keyPtr = FfiUtils.toCString(key);
    
    try {
      final result = _bindings.exists(_handle, keyPtr);
      return Ok(result == FfiConstants.success);
      
    } catch (e, stackTrace) {
      return Err(DbError.database(
        'Exception during exists operation',
        context: key,
        cause: e,
        stackTrace: stackTrace,
      ));
    } finally {
      FfiUtils.freeDartString(keyPtr);
    }
  }
  
  /// Gets all keys from the database
  /// 
  /// Returns a list of all keys currently stored in the database.
  /// 
  /// Returns:
  /// - [Ok] with list of all keys
  /// - [Err] with detailed error information on failure
  /// 
  /// Example:
  /// ```dart
  /// final result = db.keys();
  /// result.when(
  ///   ok: (keys) => print('Found ${keys.length} keys: $keys'),
  ///   err: (error) => print('Failed to get keys: $error'),
  /// );
  /// ```
  DbResult<List<String>, DbError> keys() {
    if (_closed) {
      return Err(DbError.database('Database is closed'));
    }
    
    try {
      print('DEBUG: keys() - calling _bindings.getAllKeys()');
      final resultPtr = _bindings.getAllKeys(_handle);
      print('DEBUG: keys() - getAllKeys returned pointer: $resultPtr (null=${resultPtr == nullptr})');
      
      if (FfiUtils.isNull(resultPtr)) {
        print('DEBUG: keys() - pointer is null, returning empty list');
        return const Ok([]);
      }
      
      final jsonString = FfiUtils.fromCString(resultPtr);
      print('DEBUG: keys() - extracted JSON string: "$jsonString"');
      FfiUtils.freeRustString(resultPtr, _bindings);
      
      if (jsonString == null) {
        print('DEBUG: keys() - JSON string is null after conversion');
        return Err(DbError.serialization('Received null JSON for keys'));
      }
      
      try {
        print('DEBUG: keys() - attempting to decode JSON list');
        final jsonList = jsonDecode(jsonString) as List<dynamic>;
        final keys = jsonList.cast<String>();
        print('DEBUG: keys() - successfully decoded ${keys.length} keys: $keys');
        return Ok(keys);
      } catch (e) {
        print('DEBUG: keys() - failed to decode JSON: $e');
        return Err(DbError.serialization(
          'Failed to decode keys JSON',
          cause: e,
        ));
      }
      
    } catch (e, stackTrace) {
      print('DEBUG: keys() - exception occurred: $e');
      return Err(DbError.database(
        'Exception during keys operation',
        cause: e,
        stackTrace: stackTrace,
      ));
    }
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
      print('DEBUG: all() - calling _bindings.getAll()');
      final resultPtr = _bindings.getAll(_handle);
      print('DEBUG: all() - getAll returned pointer: $resultPtr (null=${resultPtr == nullptr})');
      
      if (FfiUtils.isNull(resultPtr)) {
        print('DEBUG: all() - pointer is null, returning empty map');
        return const Ok({});
      }
      
      final jsonString = FfiUtils.fromCString(resultPtr);
      print('DEBUG: all() - extracted JSON string: "$jsonString"');
      FfiUtils.freeRustString(resultPtr, _bindings);
      
      if (jsonString == null) {
        print('DEBUG: all() - JSON string is null after conversion');
        return Err(DbError.serialization('Received null JSON for all data'));
      }
      
      try {
        print('DEBUG: all() - attempting to decode JSON map');
        final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
        final result = <String, Map<String, dynamic>>{};
        
        for (final entry in jsonMap.entries) {
          if (entry.value is Map<String, dynamic>) {
            result[entry.key] = entry.value;
          }
        }
        
        print('DEBUG: all() - successfully decoded ${result.length} records');
        return Ok(result);
      } catch (e) {
        print('DEBUG: all() - failed to decode JSON: $e');
        return Err(DbError.serialization(
          'Failed to decode all data JSON',
          cause: e,
        ));
      }
      
    } catch (e, stackTrace) {
      print('DEBUG: all() - exception occurred: $e');
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
      
      if (result == FfiConstants.success) {
        return const Ok(true);
      } else {
        return Err(DbError.database('Failed to clear database'));
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
  
  /// Serializes data to JSON string
  String _serializeData(Map<String, dynamic> data) {
    return jsonEncode(data);
  }
  
  /// Deserializes JSON string to data map
  DbResult<Map<String, dynamic>, DbError> _deserializeData(String jsonString) {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      return Ok(data);
    } catch (e) {
      return Err(DbError.serialization(
        'Failed to deserialize JSON data',
        cause: e,
      ));
    }
  }
  
  /// Generates a hash for the LocalDbModel
  String _generateHash(String key, Map<String, dynamic> data) {
    final content = '$key:${jsonEncode(data)}';
    return content.hashCode.abs().toString();
  }
  
  /// Resolves database path from name using ServerPathHelper
  static DbResult<String, DbError> _resolveDatabasePath(String name) {
    // If already an absolute path, validate and return it
    if (name.startsWith('/') || 
        name.startsWith('\\') || 
        (name.length > 1 && name[1] == ':')) {
      return ServerPathHelper.validatePath(name);
    }
    
    // If it looks like a filename (has extension), use custom path
    if (name.contains('.')) {
      return ServerPathHelper.getCustomDatabasePath(name);
    }
    
    // Otherwise, create a database name with .lmdb extension
    final dbName = name.endsWith('.lmdb') ? name : '$name.lmdb';
    return ServerPathHelper.getCustomDatabasePath(dbName);
  }
}