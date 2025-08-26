// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║                         SERVER PATH HELPER                                  ║
// ║                   Pure Dart Path Management for Servers                     ║
// ║══════════════════════════════════════════════════════════════════════════════║
// ║                                                                              ║
// ║  Author: JhonaCode (Jhonatan Ortiz)                                         ║
// ║  Contact: info@jhonacode.com                                                 ║
// ║  Module: server_path_helper.dart                                             ║
// ║  Purpose: Server-optimized path resolution for Dart backend applications    ║
// ║                                                                              ║
// ║  Description:                                                                ║
// ║    Provides path management utilities specifically designed for Dart        ║
// ║    server environments where path_provider is not available. Handles       ║
// ║    cross-platform path resolution for database storage in server apps.     ║
// ║                                                                              ║
// ║  Features:                                                                   ║
// ║    • Pure Dart implementation (no path_provider dependency)                 ║
// ║    • Server-friendly directory conventions                                   ║
// ║    • Cross-platform path resolution                                         ║
// ║    • Safe directory creation and validation                                  ║
// ║                                                                              ║
// ╚══════════════════════════════════════════════════════════════════════════════╝

import 'dart:io';
import 'package:path/path.dart' as path;
import '../models/db_result.dart';
import '../models/db_error.dart';

/// Server-optimized path management utilities for database storage
/// 
/// Designed specifically for Dart server applications where Flutter's
/// path_provider is not available. Provides sensible defaults for
/// database storage locations in server environments.
class ServerPathHelper {
  /// Default database filename
  static const String defaultDatabaseName = 'server_database.lmdb';
  
  /// Default subdirectory name for database storage
  static const String defaultSubdirectory = 'dart_db';
  
  /// Gets the default database path for server applications
  /// 
  /// Returns a server-appropriate path where the database can be safely
  /// stored with proper read/write permissions. The behavior varies by platform:
  /// 
  /// - **Linux**: `~/.local/share/dart_db/` or `/var/lib/dart_db/`
  /// - **macOS**: `~/Library/Application Support/dart_db/`
  /// - **Windows**: `%APPDATA%/dart_db/`
  /// 
  /// Returns:
  /// - [Ok] with full database file path on success
  /// - [Err] with detailed error information on failure
  /// 
  /// Example:
  /// ```dart
  /// final result = ServerPathHelper.getDefaultDatabasePath();
  /// result.when(
  ///   ok: (path) => print('Database will be stored at: $path'),
  ///   err: (error) => print('Failed to determine path: $error'),
  /// );
  /// ```
  static DbResult<String, DbError> getDefaultDatabasePath() {
    try {
      final baseDirectory = _getServerDataDirectory();
      if (baseDirectory.isErr) {
        return Err(baseDirectory.errOrNull!);
      }
      
      final dbDirectory = path.join(baseDirectory.okOrNull!, defaultSubdirectory);
      final dbPath = path.join(dbDirectory, defaultDatabaseName);
      
      return Ok(dbPath);
    } catch (e, stackTrace) {
      return Err(DbError.platform(
        'Failed to determine default database path',
        context: Platform.operatingSystem,
        cause: e,
        stackTrace: stackTrace,
      ));
    }
  }
  
  /// Gets a custom database path with the specified name
  /// 
  /// Creates a database path using the provided name in the appropriate
  /// server directory. Useful when you need multiple databases or
  /// want to customize the database filename.
  /// 
  /// Parameters:
  /// - [databaseName] - Custom name for the database file
  /// 
  /// Returns:
  /// - [Ok] with full database file path on success
  /// - [Err] with detailed error information on failure
  /// 
  /// Example:
  /// ```dart
  /// final result = ServerPathHelper.getCustomDatabasePath('user_cache.lmdb');
  /// result.when(
  ///   ok: (path) => print('Custom database path: $path'),
  ///   err: (error) => print('Failed: $error'),
  /// );
  /// ```
  static DbResult<String, DbError> getCustomDatabasePath(String databaseName) {
    // Validate database name
    final validation = _validateDatabaseName(databaseName);
    if (validation.isErr) {
      return Err(validation.errOrNull!);
    }
    
    try {
      final baseDirectory = _getServerDataDirectory();
      if (baseDirectory.isErr) {
        return Err(baseDirectory.errOrNull!);
      }
      
      final dbDirectory = path.join(baseDirectory.okOrNull!, defaultSubdirectory);
      final dbPath = path.join(dbDirectory, databaseName);
      
      return Ok(dbPath);
    } catch (e, stackTrace) {
      return Err(DbError.platform(
        'Failed to create custom database path',
        context: databaseName,
        cause: e,
        stackTrace: stackTrace,
      ));
    }
  }
  
  /// Creates a database path in a completely custom directory
  /// 
  /// Allows full control over where the database is stored by specifying
  /// both the directory and filename. Use with caution as not all directories
  /// may be writable on all platforms.
  /// 
  /// Parameters:
  /// - [directory] - Full path to the directory where database should be stored
  /// - [filename] - Name of the database file
  /// 
  /// Returns:
  /// - [Ok] with full database file path on success
  /// - [Err] with detailed error information on failure
  /// 
  /// Example:
  /// ```dart
  /// final result = ServerPathHelper.createCustomPath('/tmp/myapp', 'data.lmdb');
  /// result.when(
  ///   ok: (path) => print('Database path: $path'),
  ///   err: (error) => print('Failed: $error'),
  /// );
  /// ```
  static DbResult<String, DbError> createCustomPath(String directory, String filename) {
    // Validate inputs
    final dirValidation = _validateDirectory(directory);
    if (dirValidation.isErr) {
      return Err(dirValidation.errOrNull!);
    }
    
    final nameValidation = _validateDatabaseName(filename);
    if (nameValidation.isErr) {
      return Err(nameValidation.errOrNull!);
    }
    
    try {
      final dbPath = path.join(directory, filename);
      return Ok(dbPath);
    } catch (e) {
      return Err(DbError.validation(
        'Failed to create path from directory and filename',
        context: '$directory + $filename',
        cause: e,
      ));
    }
  }
  
  /// Ensures that the directory for the database path exists
  /// 
  /// Creates all necessary parent directories for the given database path.
  /// This method should be called before attempting to open a database.
  /// 
  /// Parameters:
  /// - [databasePath] - Full path to the database file
  /// 
  /// Returns:
  /// - [Ok] with the directory path on success
  /// - [Err] with detailed error information on failure
  /// 
  /// Example:
  /// ```dart
  /// final result = ServerPathHelper.ensureDirectoryExists('/path/to/db.lmdb');
  /// result.when(
  ///   ok: (dirPath) => print('Directory ready: $dirPath'),
  ///   err: (error) => print('Failed to create directory: $error'),
  /// );
  /// ```
  static DbResult<String, DbError> ensureDirectoryExists(String databasePath) {
    try {
      final directory = path.dirname(databasePath);
      final dir = Directory(directory);
      
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      
      // Verify the directory is writable
      final writeableResult = _verifyDirectoryWriteable(directory);
      if (writeableResult.isErr) {
        return Err(writeableResult.errOrNull!);
      }
      
      return Ok(directory);
    } catch (e, stackTrace) {
      return Err(DbError.platform(
        'Failed to create database directory',
        context: databasePath,
        cause: e,
        stackTrace: stackTrace,
      ));
    }
  }
  
  /// Gets information about the available storage space
  /// 
  /// Returns information about the file system where the database
  /// would be stored, including basic directory information.
  /// 
  /// Parameters:
  /// - [databasePath] - Database path to check storage for
  /// 
  /// Returns:
  /// - [Ok] with storage information map
  /// - [Err] with detailed error information on failure
  /// 
  /// The returned map contains:
  /// - `path`: The checked path
  /// - `exists`: Whether the directory exists
  /// - `readable`: Whether the directory is readable
  /// - `writable`: Whether the directory is writable
  /// 
  /// Example:
  /// ```dart
  /// final result = ServerPathHelper.getStorageInfo('/path/to/db.lmdb');
  /// result.when(
  ///   ok: (info) => print('Directory info: $info'),
  ///   err: (error) => print('Failed to get storage info: $error'),
  /// );
  /// ```
  static DbResult<Map<String, dynamic>, DbError> getStorageInfo(String databasePath) {
    try {
      final directory = path.dirname(databasePath);
      final dir = Directory(directory);
      
      final info = {
        'path': directory,
        'exists': dir.existsSync(),
        'readable': true, // Assume readable if we can check existence
        'writable': _isDirectoryWriteable(directory),
        'absolute': path.isAbsolute(directory),
        'normalized': path.normalize(directory),
      };
      
      return Ok(info);
    } catch (e, stackTrace) {
      return Err(DbError.platform(
        'Failed to get storage information',
        context: databasePath,
        cause: e,
        stackTrace: stackTrace,
      ));
    }
  }
  
  /// Validates and sanitizes a database path
  /// 
  /// Performs comprehensive validation of a database path including
  /// security checks, length limits, and character validation.
  /// 
  /// Parameters:
  /// - [databasePath] - The path to validate
  /// 
  /// Returns:
  /// - [Ok] with the sanitized path on success
  /// - [Err] with validation error on failure
  /// 
  /// Example:
  /// ```dart
  /// final result = ServerPathHelper.validatePath('/some/path/database.lmdb');
  /// result.when(
  ///   ok: (validPath) => print('Path is valid: $validPath'),
  ///   err: (error) => print('Invalid path: $error'),
  /// );
  /// ```
  static DbResult<String, DbError> validatePath(String databasePath) {
    if (databasePath.isEmpty) {
      return Err(DbError.validation(
        'Database path cannot be empty',
        context: 'path_validation',
      ));
    }
    
    // Check for dangerous characters
    final dangerousChars = RegExp(r'[<>:"|?*\x00-\x1f]');
    if (dangerousChars.hasMatch(databasePath)) {
      return Err(DbError.validation(
        'Database path contains invalid characters',
        context: databasePath,
      ));
    }
    
    // Check path length (most file systems have limits)
    if (databasePath.length > 260 && Platform.isWindows) {
      return Err(DbError.validation(
        'Database path exceeds Windows path length limit (260 characters)',
        context: 'length: ${databasePath.length}',
      ));
    }
    
    if (databasePath.length > 4096) {
      return Err(DbError.validation(
        'Database path exceeds maximum path length limit (4096 characters)',
        context: 'length: ${databasePath.length}',
      ));
    }
    
    try {
      final normalizedPath = path.normalize(databasePath);
      return Ok(normalizedPath);
    } catch (e) {
      return Err(DbError.validation(
        'Failed to normalize database path',
        context: databasePath,
        cause: e,
      ));
    }
  }
  
  // Private helper methods
  
  /// Gets the appropriate data directory for server applications
  static DbResult<String, DbError> _getServerDataDirectory() {
    try {
      final homeDir = Platform.environment['HOME'] ?? 
                     Platform.environment['USERPROFILE'] ?? '';
                     
      if (homeDir.isEmpty) {
        // Fallback to current directory if no home directory is available
        return Ok(Directory.current.path);
      }
      
      String baseDir;
      
      if (Platform.isLinux) {
        // Linux: ~/.local/share/ or current directory as fallback
        final xdgDataHome = Platform.environment['XDG_DATA_HOME'];
        if (xdgDataHome != null && xdgDataHome.isNotEmpty) {
          baseDir = xdgDataHome;
        } else {
          baseDir = path.join(homeDir, '.local', 'share');
        }
      } else if (Platform.isMacOS) {
        // macOS: ~/Library/Application Support/
        baseDir = path.join(homeDir, 'Library', 'Application Support');
      } else if (Platform.isWindows) {
        // Windows: %APPDATA% or %USERPROFILE%/AppData/Roaming/
        final appData = Platform.environment['APPDATA'];
        if (appData != null && appData.isNotEmpty) {
          baseDir = appData;
        } else {
          baseDir = path.join(homeDir, 'AppData', 'Roaming');
        }
      } else {
        // Unknown platform: use current directory
        baseDir = Directory.current.path;
      }
      
      return Ok(baseDir);
    } catch (e, stackTrace) {
      return Err(DbError.platform(
        'Failed to determine server data directory',
        context: Platform.operatingSystem,
        cause: e,
        stackTrace: stackTrace,
      ));
    }
  }
  
  /// Validates a database filename
  static DbResult<void, DbError> _validateDatabaseName(String filename) {
    if (filename.isEmpty) {
      return Err(DbError.validation(
        'Database filename cannot be empty',
        context: 'filename_validation',
      ));
    }
    
    // Check for invalid filename characters
    final invalidChars = RegExp(r'[<>:"/\\|?*\x00-\x1f]');
    if (invalidChars.hasMatch(filename)) {
      return Err(DbError.validation(
        'Database filename contains invalid characters',
        context: filename,
      ));
    }
    
    // Check filename length
    if (filename.length > 255) {
      return Err(DbError.validation(
        'Database filename exceeds maximum length (255 characters)',
        context: 'length: ${filename.length}',
      ));
    }
    
    // Check for reserved names (Windows)
    if (Platform.isWindows) {
      final reservedNames = [
        'CON', 'PRN', 'AUX', 'NUL',
        'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9',
        'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9',
      ];
      final nameWithoutExt = path.basenameWithoutExtension(filename).toUpperCase();
      if (reservedNames.contains(nameWithoutExt)) {
        return Err(DbError.validation(
          'Database filename uses reserved Windows name',
          context: filename,
        ));
      }
    }
    
    return const Ok(null);
  }
  
  /// Validates a directory path
  static DbResult<void, DbError> _validateDirectory(String directory) {
    if (directory.isEmpty) {
      return Err(DbError.validation(
        'Directory path cannot be empty',
        context: 'directory_validation',
      ));
    }
    
    // For servers, we allow both relative and absolute paths
    // but absolute paths are strongly recommended for production
    
    return const Ok(null);
  }
  
  /// Verifies that a directory is writeable
  static DbResult<void, DbError> _verifyDirectoryWriteable(String directory) {
    try {
      final isWriteable = _isDirectoryWriteable(directory);
      if (!isWriteable) {
        return Err(DbError.platform(
          'Directory is not writeable',
          context: directory,
        ));
      }
      return const Ok(null);
    } catch (e) {
      return Err(DbError.platform(
        'Failed to verify directory permissions',
        context: directory,
        cause: e,
      ));
    }
  }
  
  /// Checks if a directory is writeable
  static bool _isDirectoryWriteable(String directory) {
    try {
      final dir = Directory(directory);
      if (!dir.existsSync()) {
        return false;
      }
      
      // Try to create a temporary file
      final tempFile = File(path.join(directory, '.dart_db_write_test'));
      tempFile.writeAsStringSync('test');
      tempFile.deleteSync();
      
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Gets information about the current environment for debugging
  static Map<String, dynamic> getEnvironmentInfo() {
    return {
      'platform': Platform.operatingSystem,
      'version': Platform.operatingSystemVersion,
      'executable': Platform.resolvedExecutable,
      'working_directory': Directory.current.path,
      'environment': {
        'HOME': Platform.environment['HOME'],
        'USERPROFILE': Platform.environment['USERPROFILE'],
        'APPDATA': Platform.environment['APPDATA'],
        'XDG_DATA_HOME': Platform.environment['XDG_DATA_HOME'],
        'PATH': Platform.environment['PATH'],
        'LD_LIBRARY_PATH': Platform.environment['LD_LIBRARY_PATH'],
      },
    };
  }
}