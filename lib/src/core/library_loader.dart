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
    
    return [
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
    ];
  }
  
  /// Gets Linux-specific library paths
  static List<String> _getLinuxPaths() {
    final currentDir = Directory.current.path;
    final binaryDir = path.join('binary', 'linux');
    
    return [
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
    ];
  }
  
  /// Gets Windows-specific library paths
  static List<String> _getWindowsPaths() {
    final currentDir = Directory.current.path;
    final binaryDir = path.join('binary', 'windows');
    
    return [
      // Binary directory (package structure) - current and parent directories
      path.join(currentDir, binaryDir, 'liboffline_first_core.dll'),
      path.join(path.dirname(currentDir), binaryDir, 'liboffline_first_core.dll'),
      path.join(path.dirname(path.dirname(currentDir)), binaryDir, 'liboffline_first_core.dll'),
      
      // Local development fallbacks
      path.join(currentDir, 'liboffline_first_core.dll'),
      'liboffline_first_core.dll',
    ];
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