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

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:logger_rs/logger_rs.dart';
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
    Log.i('LibraryLoader: Attempting to load native library for $platform');

    // Priority loading for Linux and macOS
    if (platform == 'linux' || platform == 'macos') {
      return _loadUnixLibrary(platform);
    }

    // Fallback for other platforms
    return _loadOtherPlatforms(platform);
  }

  /// Optimized loading for Unix systems (Linux & macOS)
  static DbResult<DynamicLibrary, DbError> _loadUnixLibrary(String platform) {
    Log.d('LibraryLoader: Starting Unix library loading for $platform');

    final libraryPaths =
        platform == 'linux' ? _getLinuxServerPaths() : _getMacOSServerPaths();
    final attemptedPaths = <String>[];
    final existingPaths = <String>[];
    final loadErrors = <String, dynamic>{};

    Log.d('LibraryLoader: Will search ${libraryPaths.length} paths');

    for (final libPath in libraryPaths) {
      attemptedPaths.add(libPath);

      try {
        // For absolute paths, check if file exists first
        if (libPath.startsWith('/') || libPath.startsWith('./')) {
          final file = File(libPath);
          if (!file.existsSync()) {
            continue;
          }

          Log.i('LibraryLoader: Found library file at: $libPath');
          existingPaths.add(libPath);

          // Try to get file info for logging
          try {
            final stat = file.statSync();
            final size = stat.size;
            final perms = stat.modeString();
            Log.d(
                'LibraryLoader: File details - Size: $size bytes, Permissions: $perms');
          } catch (_) {
            // Ignore stat errors
          }
        }

        Log.d('LibraryLoader: Attempting to load: $libPath');
        final lib = DynamicLibrary.open(libPath);
        Log.i('LibraryLoader: ✓ Successfully loaded library from: $libPath');
        return Ok(lib);
      } catch (e) {
        // Store the error for the first existing path
        if (existingPaths.isNotEmpty && !loadErrors.containsKey(libPath)) {
          Log.e('LibraryLoader: Failed to load $libPath - Error: $e');
          loadErrors[libPath] = e;
        }
        continue;
      }
    }

    // Build helpful error message
    Log.e(
        'LibraryLoader: Failed to load library after trying ${attemptedPaths.length} paths');

    if (existingPaths.isNotEmpty) {
      Log.w('LibraryLoader: Library file was found but could not be loaded');
      for (final p in existingPaths) {
        Log.w('  - Found at: $p');
        if (loadErrors.containsKey(p)) {
          Log.e('    Error: ${loadErrors[p]}');
        }
      }
    } else {
      Log.e('LibraryLoader: Library file not found in any search path');
    }

    final errorMessage = StringBuffer();
    errorMessage.writeln('Failed to load native library for $platform');
    errorMessage.writeln('');

    if (existingPaths.isNotEmpty) {
      final firstPath = existingPaths.first;
      errorMessage.writeln('✓ Library file found at:');
      errorMessage.writeln('  $firstPath');
      errorMessage.writeln('');

      if (loadErrors.containsKey(firstPath)) {
        errorMessage.writeln('✗ But failed to load it:');
        errorMessage.writeln('  ${loadErrors[firstPath]}');
        errorMessage.writeln('');
      }

      errorMessage.writeln('Possible solutions:');
      errorMessage.writeln('');
      errorMessage.writeln('1. Run diagnostic script:');
      errorMessage.writeln('   cd ~/.pub-cache/git/dart_db-*/');
      errorMessage.writeln('   bash scripts/diagnose_linux.sh');
      errorMessage.writeln('');
      errorMessage.writeln('2. Check file permissions:');
      errorMessage.writeln('   chmod +x $firstPath');
      errorMessage.writeln('');
      errorMessage.writeln('3. Check for missing dependencies:');
      errorMessage.writeln('   ldd $firstPath');
      errorMessage.writeln('');
      errorMessage.writeln('4. Install to system directory:');
      errorMessage.writeln('   sudo cp $firstPath /usr/local/lib/');
      errorMessage.writeln('   sudo ldconfig');
    } else {
      errorMessage.writeln(
          'This usually means dart_db cannot find liboffline_first_core.${platform == 'linux' ? 'so' : 'dylib'}');
      errorMessage.writeln('');
      errorMessage.writeln(
          '💡 Quick fix: Run `dart pub get` to regenerate package configuration');
      errorMessage.writeln('');
      errorMessage.writeln(
          '📝 For detailed solutions, see: https://github.com/jhonacodes/dart_db/blob/main/TROUBLESHOOTING.md');
    }

    return Err(DbError.ffi(
      errorMessage.toString(),
      context: 'Unix library loading',
      cause: 'Attempted ${attemptedPaths.length} paths',
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

    // PRIORITY 1: Try to read package location from package_config.json
    // This is the most reliable method as Dart maintains this file
    final packageConfigPaths = _getPackagePathsFromConfig();
    paths.addAll(packageConfigPaths);

    // PRIORITY 2: Check for .pub-cache git repositories
    final homeDir = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    if (homeDir.isNotEmpty) {
      final pubCacheGit = path.join(homeDir, '.pub-cache', 'git');
      final gitDir = Directory(pubCacheGit);

      if (gitDir.existsSync()) {
        try {
          // Look for ANY directory that might contain dart_db
          // Not just dart_db-* but also variations
          final entries = gitDir.listSync().whereType<Directory>().toList();

          for (final entry in entries) {
            final dirName = path.basename(entry.path);
            // Check if directory name contains dart_db OR dart-db OR dartdb
            if (dirName.contains('dart_db') ||
                dirName.contains('dart-db') ||
                dirName.contains('dartdb')) {
              paths.add(entry.path);
            }
          }
        } catch (e) {
          // Ignore errors when scanning .pub-cache
        }
      }

      // Also check hosted packages (pub.dev)
      final pubCacheHosted = path.join(homeDir, '.pub-cache', 'hosted');
      final hostedDir = Directory(pubCacheHosted);

      if (hostedDir.existsSync()) {
        try {
          // Look in all pub.dev mirrors
          for (final mirror in hostedDir.listSync().whereType<Directory>()) {
            final dartDbDirs = mirror
                .listSync()
                .whereType<Directory>()
                .where((dir) => path.basename(dir.path).startsWith('dart_db-'))
                .toList();

            for (final entry in dartDbDirs) {
              paths.add(entry.path);
            }
          }
        } catch (e) {
          // Ignore errors when scanning .pub-cache
        }
      }
    }

    // PRIORITY 3: Check current directory for local development
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

    // PRIORITY 4: Check parent directories (in case we're in a subdirectory)
    var parentDir = path.dirname(currentDir);
    for (var i = 0; i < 3; i++) {
      final parentPubspec = File(path.join(parentDir, 'pubspec.yaml'));
      if (parentPubspec.existsSync()) {
        try {
          final content = parentPubspec.readAsStringSync();
          if (content.contains('name: dart_db')) {
            paths.add(parentDir);
            break;
          }
        } catch (e) {
          // Ignore
        }
      }
      parentDir = path.dirname(parentDir);
    }

    return paths;
  }

  /// Gets package paths by reading .dart_tool/package_config.json
  ///
  /// This is the most reliable method as Dart maintains this file with
  /// exact package locations.
  static List<String> _getPackagePathsFromConfig() {
    final paths = <String>[];
    Log.d('LibraryLoader: Searching for package_config.json...');

    try {
      // Check in current directory
      var currentDir = Directory.current.path;
      Log.d('LibraryLoader: Starting search from: $currentDir');

      // Try up to 3 parent directories
      for (var i = 0; i < 4; i++) {
        final packageConfigFile =
            File(path.join(currentDir, '.dart_tool', 'package_config.json'));

        if (packageConfigFile.existsSync()) {
          Log.i(
              'LibraryLoader: Found package_config.json at: ${packageConfigFile.path}');

          try {
            final configContent = packageConfigFile.readAsStringSync();
            final config = jsonDecode(configContent) as Map<String, dynamic>;

            if (config.containsKey('packages')) {
              final packages = config['packages'] as List;
              Log.d('LibraryLoader: Scanning ${packages.length} packages...');

              for (final package in packages) {
                if (package is Map<String, dynamic> &&
                    package['name'] == 'dart_db') {
                  Log.i('LibraryLoader: Found dart_db package in config');

                  // Extract package root path from rootUri
                  final rootUri = package['rootUri'] as String?;
                  final packageUri = package['packageUri'] as String?;

                  Log.d(
                      'LibraryLoader: rootUri: $rootUri, packageUri: $packageUri');

                  if (rootUri != null) {
                    String packageRootPath;

                    if (rootUri.startsWith('file://')) {
                      // Absolute file URI - convert to path
                      packageRootPath = Uri.parse(rootUri).toFilePath();
                      Log.d(
                          'LibraryLoader: Converted file:// URI to path: $packageRootPath');
                    } else if (rootUri.startsWith('../')) {
                      // Relative path from .dart_tool directory
                      final dartToolDir = path.join(currentDir, '.dart_tool');
                      packageRootPath =
                          path.normalize(path.join(dartToolDir, rootUri));
                      Log.d(
                          'LibraryLoader: Resolved relative path: $packageRootPath');
                    } else {
                      // Try to resolve as relative path from current directory
                      packageRootPath =
                          path.normalize(path.join(currentDir, rootUri));
                      Log.d(
                          'LibraryLoader: Resolved as relative from current dir: $packageRootPath');
                    }

                    // If packageUri is "lib/", rootUri points to package root
                    // If not specified, we may need to go up one level
                    if (packageUri == 'lib/') {
                      // rootUri is already at package root
                      paths.add(packageRootPath);
                      Log.i(
                          'LibraryLoader: Added package root path: $packageRootPath');
                    } else {
                      // rootUri might be pointing to lib/ directory
                      // Check if it ends with /lib or /lib/
                      if (packageRootPath.endsWith('/lib') ||
                          packageRootPath.endsWith('/lib/')) {
                        // Go up one level to package root
                        packageRootPath = path.dirname(packageRootPath);
                        Log.d(
                            'LibraryLoader: Adjusted to package root: $packageRootPath');
                      }
                      paths.add(packageRootPath);
                      Log.i(
                          'LibraryLoader: Added package path: $packageRootPath');
                    }
                  }
                }
              }
            }
          } catch (e) {
            Log.w('LibraryLoader: Error parsing package_config.json: $e');
            // Ignore JSON parsing errors - continue searching
          }

          // Found a package_config.json, don't search parent directories
          break;
        }

        // Move to parent directory
        final parentDir = path.dirname(currentDir);
        if (parentDir == currentDir) break; // Reached root
        currentDir = parentDir;
      }

      if (paths.isEmpty) {
        Log.w('LibraryLoader: No dart_db package found in package_config.json');
      } else {
        Log.i(
            'LibraryLoader: Found ${paths.length} package path(s) from config');
      }
    } catch (e) {
      Log.e('LibraryLoader: Error reading package_config.json: $e');
      // Ignore any errors in this method
    }

    return paths;
  }

  /// Gets information about the current environment for debugging
  ///
  /// Returns detailed information about the system environment and library
  /// search paths. Useful for troubleshooting library loading issues.
  ///
  /// Example:
  /// ```dart
  /// final info = LibraryLoader.getEnvironmentInfo();
  /// print('Platform: ${info['platform']}');
  /// print('Working Directory: ${info['working_directory']}');
  /// print('\nLibrary Search Paths:');
  /// for (final path in info['library_search_paths']) {
  ///   print('  - $path');
  /// }
  /// ```
  static Map<String, dynamic> getEnvironmentInfo() {
    final platform = Platform.operatingSystem;
    final searchPaths = platform == 'linux'
        ? _getLinuxServerPaths()
        : (platform == 'macos' ? _getMacOSServerPaths() : _getWindowsPaths());

    // Check which paths actually exist
    final existingPaths = <String>[];
    for (final libPath in searchPaths) {
      if (libPath.startsWith('/') || libPath.startsWith('./')) {
        final file = File(libPath);
        if (file.existsSync()) {
          existingPaths.add(libPath);
        }
      }
    }

    return {
      'platform': platform,
      'version': Platform.operatingSystemVersion,
      'executable': Platform.resolvedExecutable,
      'working_directory': Directory.current.path,
      'dart_tool_exists':
          Directory(path.join(Directory.current.path, '.dart_tool'))
              .existsSync(),
      'package_config_exists': File(path.join(
              Directory.current.path, '.dart_tool', 'package_config.json'))
          .existsSync(),
      'LD_LIBRARY_PATH': Platform.environment['LD_LIBRARY_PATH'],
      'PATH': Platform.environment['PATH'],
      'HOME': Platform.environment['HOME'],
      'library_search_paths': searchPaths,
      'library_search_count': searchPaths.length,
      'existing_library_paths': existingPaths,
      'library_found': existingPaths.isNotEmpty,
      'package_paths_from_config': _getPackagePathsFromConfig(),
    };
  }

  /// Prints debugging information about library loading
  ///
  /// This is a convenience method that prints formatted debugging information
  /// to help troubleshoot library loading issues.
  ///
  /// Example:
  /// ```dart
  /// LibraryLoader.printDebugInfo();
  /// ```
  static void printDebugInfo() {
    print('╔══════════════════════════════════════════════════════════════╗');
    print('║           DART_DB LIBRARY LOADER DEBUG INFO                 ║');
    print('╚══════════════════════════════════════════════════════════════╝');
    print('');

    final info = getEnvironmentInfo();

    print('Platform Information:');
    print('  Platform: ${info['platform']}');
    print('  Version: ${info['version']}');
    print('  Working Directory: ${info['working_directory']}');
    print('  Dart Executable: ${info['executable']}');
    print('');

    print('Package Configuration:');
    print('  .dart_tool exists: ${info['dart_tool_exists']}');
    print('  package_config.json exists: ${info['package_config_exists']}');
    print('');

    final packagePaths = info['package_paths_from_config'] as List;
    if (packagePaths.isNotEmpty) {
      print('Package Paths from Config:');
      for (final p in packagePaths) {
        print('  ✓ $p');
      }
      print('');
    }

    print('Environment Variables:');
    print('  HOME: ${info['HOME']}');
    print('  LD_LIBRARY_PATH: ${info['LD_LIBRARY_PATH'] ?? '(not set)'}');
    print('');

    final existingPaths = info['existing_library_paths'] as List;
    if (existingPaths.isNotEmpty) {
      print('✓ Library Found at:');
      for (final p in existingPaths) {
        print('  $p');
      }
    } else {
      print('✗ Library NOT Found');
      print('');
      print('Searched ${info['library_search_count']} paths:');
      final searchPaths = info['library_search_paths'] as List;
      final maxDisplay = 10;
      for (var i = 0; i < searchPaths.length && i < maxDisplay; i++) {
        print('  ${i + 1}. ${searchPaths[i]}');
      }
      if (searchPaths.length > maxDisplay) {
        print('  ... and ${searchPaths.length - maxDisplay} more paths');
      }
    }

    print('');
    print('═══════════════════════════════════════════════════════════════');
  }
}
