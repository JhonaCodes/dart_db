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
    // Library search paths in order of preference for backend deployment
    final libraryPaths = [
      // Local development (same directory as executable)
      './liboffline_first_core.so',
      
      // Local lib directory
      './lib/liboffline_first_core.so',
      
      // Relative to project root
      '../lib/liboffline_first_core.so',
      'lib/liboffline_first_core.so',
      
      // Linux server common locations (let system find)
      'liboffline_first_core.so',
    ];
    
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
Failed to load LMDB native library for Linux backend.

Attempted paths:
${attemptedPaths.map((path) => '  - $path').join('\n')}

Solutions:
1. Place liboffline_first_core.so in your application directory
2. Add library path to LD_LIBRARY_PATH environment variable
3. Install library system-wide (consult your Linux distribution docs)
4. Use Docker with the library included in container

For development: Place liboffline_first_core.so in the same directory as your Dart executable.
For production: Use Docker or install system-wide according to your deployment strategy.
''';
    
    return Err(DbError.ffi(
      'Failed to load native library',
      context: 'Linux library loading',
      cause: errorMessage,
    ));
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