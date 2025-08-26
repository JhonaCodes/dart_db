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

/// Linux server library loader for LMDB database
/// 
/// Handles loading the native library in Linux server environments
/// with multiple fallback strategies for different deployment scenarios.
class LibraryLoader {
  /// Loads the LMDB library for Linux backend applications
  /// 
  /// Tries multiple common locations where the library might be installed
  /// in server environments, from local development to production deployments.
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
    // Detect platform and get appropriate library paths
    final platform = Platform.operatingSystem;
    final libraryPaths = _getPlatformSpecificPaths(platform);
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
        // Continue to next path
        continue;
      }
    }
    
    // If we get here, no library was found
    final errorMessage = '''
Failed to load native library for $platform.

Attempted paths:
${attemptedPaths.map((path) => '  - $path').join('\n')}

Solutions:
1. Ensure the correct binary is in your application directory
2. For macOS: Use the .dylib binary in binary/macos/
3. For Linux: Use the .so binary in binary/linux/
4. Set library path environment variable (LD_LIBRARY_PATH on Linux, DYLD_LIBRARY_PATH on macOS)

Binary locations:
- macOS: binary/macos/liboffline_first_core.dylib
- Linux: binary/linux/liboffline_first_core.so
- Windows: binary/windows/liboffline_first_core.dll (future)
''';
    
    return Err(DbError.ffi(
      'Failed to load native library',
      context: '$platform library loading',
      cause: errorMessage,
    ));
  }
  
  /// Gets platform-specific library search paths
  static List<String> _getPlatformSpecificPaths(String platform) {
    switch (platform.toLowerCase()) {
      case 'macos':
        return _getMacOSPaths();
      case 'linux':
        return _getLinuxPaths();
      case 'windows':
        return _getWindowsPaths();
      default:
        return _getLinuxPaths(); // Default to Linux
    }
  }
  
  /// Gets macOS-specific library paths
  static List<String> _getMacOSPaths() {
    final currentDir = Directory.current.path;
    final binaryDir = path.join('binary', 'macos');
    
    // Try to find package directory
    final packagePaths = _getPackageSearchPaths();
    
    final paths = <String>[];
    
    // Add package-specific paths first (highest priority)
    for (final packagePath in packagePaths) {
      paths.addAll([
        path.join(packagePath, binaryDir, 'liboffline_first_core.dylib'),
        path.join(packagePath, binaryDir, 'liboffline_first_core_x86_64.dylib'),
      ]);
    }
    
    // Add current directory paths
    paths.addAll([
      // Binary directory (package structure) - current and parent directories
      path.join(currentDir, binaryDir, 'liboffline_first_core.dylib'),
      path.join(path.dirname(currentDir), binaryDir, 'liboffline_first_core.dylib'),
      path.join(path.dirname(path.dirname(currentDir)), binaryDir, 'liboffline_first_core.dylib'),
      
      // Architecture-specific paths
      path.join(currentDir, binaryDir, 'liboffline_first_core_x86_64.dylib'),
      path.join(path.dirname(currentDir), binaryDir, 'liboffline_first_core_x86_64.dylib'),
      
      // Local development fallbacks
      path.join(currentDir, 'liboffline_first_core.dylib'),
      'liboffline_first_core.dylib',
    ]);
    
    return paths;
  }
  
  /// Gets Linux-specific library paths
  static List<String> _getLinuxPaths() {
    final currentDir = Directory.current.path;
    final binaryDir = path.join('binary', 'linux');
    
    // Try to find package directory
    final packagePaths = _getPackageSearchPaths();
    
    final paths = <String>[];
    
    // Add package-specific paths first (highest priority)
    for (final packagePath in packagePaths) {
      paths.add(path.join(packagePath, binaryDir, 'liboffline_first_core.so'));
    }
    
    // Add current directory paths
    paths.addAll([
      // Binary directory (package structure) - current and parent directories
      path.join(currentDir, binaryDir, 'liboffline_first_core.so'),
      path.join(path.dirname(currentDir), binaryDir, 'liboffline_first_core.so'),
      path.join(path.dirname(path.dirname(currentDir)), binaryDir, 'liboffline_first_core.so'),
      
      // Local development fallbacks
      path.join(currentDir, 'liboffline_first_core.so'),
      path.join(currentDir, 'lib', 'liboffline_first_core.so'),
      path.join('lib', 'liboffline_first_core.so'),
      
      // System library locations (let system find)
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
      path.join(path.dirname(currentDir), binaryDir, 'liboffline_first_core.dll'),
      path.join(path.dirname(path.dirname(currentDir)), binaryDir, 'liboffline_first_core.dll'),
      
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
      'put',
      'get',
      'delete',
      'exists',
      'get_all_keys',
      'get_all',
      'get_stats',
      'clear',
      'close_db',
      'free_string',
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
    final homeDir = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '';
    if (homeDir.isNotEmpty) {
      final pubCacheGit = path.join(homeDir, '.pub-cache', 'git');
      final gitDir = Directory(pubCacheGit);
      
      if (gitDir.existsSync()) {
        try {
          // Look for dart_db-* directories
          final entries = gitDir.listSync()
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
    
    // Check relative paths for local development
    final currentDir = Directory.current.path;
    final possibleLocalPaths = [
      '.',
      '..',
      '../..',
      '../../..',
      '../dart_db',
      '../../dart_db',
      '../../../dart_db',
      '../../../../04_Librarys/dart_db',
    ];
    
    for (final relativePath in possibleLocalPaths) {
      final fullPath = path.normalize(path.join(currentDir, relativePath));
      final pubspecFile = File(path.join(fullPath, 'pubspec.yaml'));
      
      if (pubspecFile.existsSync()) {
        try {
          final content = pubspecFile.readAsStringSync();
          if (content.contains('name: dart_db')) {
            paths.add(fullPath);
          }
        } catch (e) {
          // Ignore errors reading pubspec.yaml
        }
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