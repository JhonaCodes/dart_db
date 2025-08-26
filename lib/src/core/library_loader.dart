// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║                            LIBRARY LOADER                                   ║
// ║                    Linux Server Library Loading for Backend                 ║
// ║══════════════════════════════════════════════════════════════════════════════║
// ║                                                                              ║
// ║  Author: JhonaCode (Jhonatan Ortiz)                                         ║
// ║  Contact: info@jhonacode.com                                                 ║
// ║  Module: library_loader.dart                                                 ║
// ║  Purpose: Load native LMDB library on Linux servers                        ║
// ║                                                                              ║
// ║  Description:                                                                ║
// ║    Handles loading the native LMDB library specifically for Linux          ║
// ║    server environments. Optimized for backend applications with            ║
// ║    predictable deployment patterns.                                         ║
// ║                                                                              ║
// ║  Features:                                                                   ║
// ║    • Linux-optimized library loading                                        ║
// ║    • Multiple fallback strategies                                            ║
// ║    • Server-friendly error reporting                                        ║
// ║    • Development and production support                                     ║
// ║                                                                              ║
// ╚══════════════════════════════════════════════════════════════════════════════╝

import 'dart:ffi';
import 'dart:io';
import 'package:path/path.dart' as path;
import '../models/db_result.dart';
import '../models/db_error.dart';

/// Server-optimized library loader for LMDB database (Linux & macOS focused)
///
/// Handles loading the native library primarily for Linux and macOS server
/// environments with optimized fallback strategies for production deployments.
class LibraryLoader {
  /// Loads the LMDB library for server applications (Linux & macOS optimized)
  ///
  /// Prioritizes Linux and macOS with optimized path resolution for server
  /// environments. Windows support is secondary.
  ///
  /// Returns:
  /// - [Ok] with loaded [DynamicLibrary] on success
  /// - [Err] with detailed error information on failure
  ///
  /// Example:
  /// ```dart
  /// final result = LibraryLoader.loadLibrary();
  /// result.when(
  ///   ok: (lib) => print('Library loaded successfully'),
  ///   err: (error) => print('Failed to load: $error'),
  /// );
  /// ```
  static DbResult<DynamicLibrary, DbError> loadLibrary() {
    final platform = Platform.operatingSystem;

    // Priority loading for Linux and macOS
    if (platform == 'linux' || platform == 'macos') {
      return _loadUnixLibrary(platform);
    }

    // Fallback for other platforms
    return _loadOtherPlatforms(platform);
  }

  /// Optimized loading for Unix systems (Linux & macOS)
  static DbResult<DynamicLibrary, DbError> _loadUnixLibrary(String platform) {
    final libraryPaths =
        platform == 'linux' ? _getLinuxServerPaths() : _getMacOSServerPaths();
    final attemptedPaths = <String>[];

    for (final libPath in libraryPaths) {
      attemptedPaths.add(libPath);

      try {
        // For absolute paths, check if file exists first
        if (libPath.startsWith('/') || libPath.startsWith('./')) {
          final file = File(libPath);
          if (!file.existsSync()) {
            continue;
          }
        }

        final lib = DynamicLibrary.open(libPath);
        return Ok(lib);
      } catch (e) {
        continue;
      }
    }

    return Err(DbError.ffi(
      'Failed to load native library for $platform',
      context: 'Unix library loading',
      cause: 'Attempted paths: ${attemptedPaths.join(', ')}',
    ));
  }

  /// Fallback loading for other platforms
  static DbResult<DynamicLibrary, DbError> _loadOtherPlatforms(
      String platform) {
    final libraryPaths = _getPlatformSpecificPaths(platform);
    final attemptedPaths = <String>[];

    for (final libPath in libraryPaths) {
      attemptedPaths.add(libPath);

      try {
        if (libPath.startsWith('/') || libPath.startsWith('./')) {
          final file = File(libPath);
          if (!file.existsSync()) {
            continue;
          }
        }

        final lib = DynamicLibrary.open(libPath);
        return Ok(lib);
      } catch (e) {
        continue;
      }
    }

    return Err(DbError.ffi(
      'Failed to load native library for $platform (limited support)',
      context: '$platform library loading',
      cause:
          'dart_db is optimized for Linux and macOS. Attempted: ${attemptedPaths.join(', ')}',
    ));
  }

  /// Gets platform-specific library search paths (legacy support)
  static List<String> _getPlatformSpecificPaths(String platform) {
    switch (platform.toLowerCase()) {
      case 'macos':
        return _getMacOSServerPaths();
      case 'linux':
        return _getLinuxServerPaths();
      case 'windows':
        return _getWindowsPaths();
      default:
        return _getLinuxServerPaths(); // Default to Linux
    }
  }

  /// Gets macOS server-optimized library paths
  static List<String> _getMacOSServerPaths() {
    final currentDir = Directory.current.path;
    final binaryDir = path.join('binary', 'macos');

    // Try to find package directory (optimized search)
    final packagePaths = _getPackageSearchPaths();

    final paths = <String>[];

    // Priority 1: Package-specific paths (highest priority for servers)
    for (final packagePath in packagePaths) {
      paths.addAll([
        path.join(packagePath, binaryDir, 'liboffline_first_core.dylib'),
        path.join(packagePath, binaryDir, 'liboffline_first_core_arm64.dylib'),
        path.join(packagePath, binaryDir, 'liboffline_first_core_x86_64.dylib'),
      ]);
    }

    // Priority 2: Server deployment paths
    paths.addAll([
      // Standard server library locations
      '/usr/local/lib/liboffline_first_core.dylib',
      '/opt/homebrew/lib/liboffline_first_core.dylib',
      '/opt/local/lib/liboffline_first_core.dylib',

      // Application-relative paths (Docker/container deployments)
      path.join(currentDir, 'lib', 'liboffline_first_core.dylib'),
      path.join(currentDir, binaryDir, 'liboffline_first_core.dylib'),
      path.join(currentDir, binaryDir, 'liboffline_first_core_arm64.dylib'),

      // Parent directory paths (common server structures)
      path.join(
          path.dirname(currentDir), binaryDir, 'liboffline_first_core.dylib'),
      path.join(path.dirname(path.dirname(currentDir)), binaryDir,
          'liboffline_first_core.dylib'),

      // Fallbacks
      path.join(currentDir, 'liboffline_first_core.dylib'),
      'liboffline_first_core.dylib',
    ]);

    return paths;
  }

  /// Gets Linux server-optimized library paths
  static List<String> _getLinuxServerPaths() {
    final currentDir = Directory.current.path;
    final binaryDir = path.join('binary', 'linux');

    // Try to find package directory (optimized search)
    final packagePaths = _getPackageSearchPaths();

    final paths = <String>[];

    // Priority 1: Package-specific paths (highest priority for servers)
    for (final packagePath in packagePaths) {
      paths.add(path.join(packagePath, binaryDir, 'liboffline_first_core.so'));
    }

    // Priority 2: Standard Linux server library locations
    paths.addAll([
      // System library paths (production servers)
      '/usr/local/lib/liboffline_first_core.so',
      '/usr/lib/liboffline_first_core.so',
      '/usr/lib64/liboffline_first_core.so',
      '/lib/liboffline_first_core.so',
      '/lib64/liboffline_first_core.so',

      // Container/Docker deployment paths
      path.join(currentDir, 'lib', 'liboffline_first_core.so'),
      path.join(currentDir, binaryDir, 'liboffline_first_core.so'),

      // Application-relative paths (common server structures)
      path.join(path.dirname(currentDir), 'lib', 'liboffline_first_core.so'),
      path.join(
          path.dirname(currentDir), binaryDir, 'liboffline_first_core.so'),
      path.join(path.dirname(path.dirname(currentDir)), binaryDir,
          'liboffline_first_core.so'),

      // Development and fallback paths
      path.join(currentDir, 'liboffline_first_core.so'),
      './liboffline_first_core.so',
      'liboffline_first_core.so',
    ]);

    return paths;
  }

  /// Gets Windows-specific library paths
  static List<String> _getWindowsPaths() {
    final currentDir = Directory.current.path;
    final binaryDir = path.join('binary', 'windows');

    // Try to find package directory
    final packagePaths = _getPackageSearchPaths();

    final paths = <String>[];

    // Add package-specific paths first (highest priority)
    for (final packagePath in packagePaths) {
      paths.add(path.join(packagePath, binaryDir, 'liboffline_first_core.dll'));
    }

    // Add current directory paths
    paths.addAll([
      // Binary directory (package structure) - current and parent directories
      path.join(currentDir, binaryDir, 'liboffline_first_core.dll'),
      path.join(
          path.dirname(currentDir), binaryDir, 'liboffline_first_core.dll'),
      path.join(path.dirname(path.dirname(currentDir)), binaryDir,
          'liboffline_first_core.dll'),

      // Local development fallbacks
      path.join(currentDir, 'liboffline_first_core.dll'),
      'liboffline_first_core.dll',
    ]);

    return paths;
  }

  /// Validates that a loaded library contains all required functions
  ///
  /// Performs validation to ensure the library is compatible and contains
  /// all expected function symbols.
  ///
  /// Parameters:
  /// - [lib] - The loaded dynamic library to validate
  ///
  /// Returns:
  /// - [Ok] with the library if validation passes
  /// - [Err] with validation error if functions are missing
  static DbResult<DynamicLibrary, DbError> validateLibrary(
    DynamicLibrary lib,
  ) {
    const requiredFunctions = [
      'create_db',
      'post_data',
      'put_data',
      'get_by_id',
      'delete_by_id',
      'get_all',
      'clear_all_records',
      'close_database',
    ];

    final missingFunctions = <String>[];

    for (final functionName in requiredFunctions) {
      try {
        lib.lookup(functionName);
      } catch (e) {
        missingFunctions.add(functionName);
      }
    }

    if (missingFunctions.isNotEmpty) {
      return Err(DbError.ffi(
        'Library missing required functions',
        context: 'Missing: ${missingFunctions.join(', ')}',
      ));
    }

    return Ok(lib);
  }

  /// Gets potential package search paths for finding binaries
  ///
  /// Searches common locations where pub caches dart_db package,
  /// including git repositories and local paths.
  static List<String> _getPackageSearchPaths() {
    final paths = <String>[];

    // Check for .pub-cache git repositories
    final homeDir = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    if (homeDir.isNotEmpty) {
      final pubCacheGit = path.join(homeDir, '.pub-cache', 'git');
      final gitDir = Directory(pubCacheGit);

      if (gitDir.existsSync()) {
        try {
          // Look for dart_db-* directories
          final entries = gitDir
              .listSync()
              .whereType<Directory>()
              .where((dir) => path.basename(dir.path).startsWith('dart_db-'))
              .toList();

          for (final entry in entries) {
            paths.add(entry.path);
          }
        } catch (e) {
          // Ignore errors when scanning .pub-cache
        }
      }
    }

    // Check current directory for local development
    final currentDir = Directory.current.path;
    final pubspecFile = File(path.join(currentDir, 'pubspec.yaml'));

    if (pubspecFile.existsSync()) {
      try {
        final content = pubspecFile.readAsStringSync();
        if (content.contains('name: dart_db')) {
          paths.add(currentDir);
        }
      } catch (e) {
        // Ignore errors reading pubspec.yaml
      }
    }

    return paths;
  }

  /// Gets information about the current environment for debugging
  static Map<String, dynamic> getEnvironmentInfo() {
    return {
      'platform': Platform.operatingSystem,
      'version': Platform.operatingSystemVersion,
      'executable': Platform.resolvedExecutable,
      'working_directory': Directory.current.path,
      'LD_LIBRARY_PATH': Platform.environment['LD_LIBRARY_PATH'],
      'PATH': Platform.environment['PATH'],
      'HOME': Platform.environment['HOME'],
    };
  }
}
