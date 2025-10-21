// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║                        DART_DB DEBUG EXAMPLE                                 ║
// ║                  Diagnostic Tool for Library Loading                         ║
// ╚══════════════════════════════════════════════════════════════════════════════╝
//
// This example shows how to debug library loading issues with dart_db.
// Run this if you encounter "Failed to load native library" errors.
//
// Usage:
//   dart run example/debug.dart

import 'package:dart_db/dart_db.dart';

void main() {
  print('\n');
  print('═══════════════════════════════════════════════════════════════');
  print('          DART_DB DIAGNOSTIC TOOL');
  print('═══════════════════════════════════════════════════════════════');
  print('\n');

  // Print detailed debugging information
  LibraryLoader.printDebugInfo();

  print('\n');
  print('───────────────────────────────────────────────────────────────');
  print('Testing Database Connection...');
  print('───────────────────────────────────────────────────────────────');
  print('\n');

  // Try to open a database
  final result = DB.open('debug_test');

  result.when(
    ok: (db) {
      print('✓ SUCCESS! Database opened successfully.');
      print('  Everything is working correctly.');
      print('');

      // Try a simple operation
      final storeResult = db.post('test_key', {'message': 'Hello from debug!'});

      storeResult.when(
        ok: (data) {
          print('✓ Data stored successfully: $data');

          // Try to read it back
          final readResult = db.get('test_key');
          readResult.when(
            ok: (readData) {
              print('✓ Data retrieved successfully: $readData');
            },
            err: (error) {
              print('✗ Failed to retrieve data: $error');
            },
          );
        },
        err: (error) {
          print('✗ Failed to store data: $error');
        },
      );

      // Clean up
      db.close();
      print('');
      print('✓ Database closed.');
    },
    err: (error) {
      print('✗ FAILED to open database.');
      print('');
      print('Error Details:');
      print('  Type: ${error.type}');
      print('  Message: ${error.message}');
      if (error.context != null) {
        print('  Context: ${error.context}');
      }
      if (error.cause != null) {
        print('  Cause: ${error.cause}');
      }
      print('');
      print('┌───────────────────────────────────────────────────────────┐');
      print('│                    TROUBLESHOOTING STEPS                   │');
      print('└───────────────────────────────────────────────────────────┘');
      print('');
      print('1. Check the diagnostic information above');
      print('   - Is "library_found" set to true?');
      print('   - Are there any paths in "existing_library_paths"?');
      print('');
      print('2. Try regenerating package configuration:');
      print('   cd your_project');
      print('   dart pub get');
      print('');
      print('3. Check file permissions:');
      print('   If a library path is shown above, ensure it has');
      print('   execute permissions (chmod +x path/to/lib.so)');
      print('');
      print('4. For detailed solutions, see:');
      print(
          '   https://github.com/jhonacodes/dart_db/blob/main/TROUBLESHOOTING.md');
      print('');
    },
  );

  print('');
  print('═══════════════════════════════════════════════════════════════');
  print('          DIAGNOSTIC COMPLETE');
  print('═══════════════════════════════════════════════════════════════');
  print('\n');
}
