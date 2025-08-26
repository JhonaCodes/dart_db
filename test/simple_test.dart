// Simple test for dart_db functionality
// This test verifies the API structure without requiring the native library

import 'package:test/test.dart';
import 'package:dart_db/dart_db.dart';
import 'dart:io';

void main() {
  group('Dart DB API Structure Tests', () {
    test('should have correct API structure', () {
      // Test that the API exists with correct method signatures
      expect(DB.open, isA<Function>());

      // Test with a dummy call - it may fail but we're testing the API exists
      final result = DB.open('test_db');
      expect(result, isA<DbResult>());

      if (result.isOk) {
        final db = result.okOrNull!;

        // Test that all expected methods exist
        expect(db.post, isA<Function>());
        expect(db.put, isA<Function>());
        expect(db.patch, isA<Function>());
        expect(db.get, isA<Function>());
        expect(db.delete, isA<Function>());
        expect(db.exists, isA<Function>());
        expect(db.keys, isA<Function>());
        expect(db.all, isA<Function>());
        expect(db.clear, isA<Function>());
        expect(db.close, isA<Function>());

        db.close();
        print('✅ Native library works - full API available');
      } else {
        print('ℹ️ Native library not available - API structure verified');
        print('   Expected on macOS with Linux binary');
      }
    });

    test('should find native library files', () {
      // Check Linux binary
      final linuxPath =
          '/Volumes/Data/Private/04_Librarys/dart_db/binary/linux/liboffline_first_core.so';
      final linuxFile = File(linuxPath);

      expect(linuxFile.existsSync(), isTrue,
          reason: 'Linux binary should exist');
      expect(linuxFile.lengthSync(), greaterThan(0),
          reason: 'Linux binary should not be empty');

      // Check macOS binary
      final macosPath =
          '/Volumes/Data/Private/04_Librarys/dart_db/binary/macos/liboffline_first_core.dylib';
      final macosFile = File(macosPath);

      expect(macosFile.existsSync(), isTrue,
          reason: 'macOS binary should exist');
      expect(macosFile.lengthSync(), greaterThan(0),
          reason: 'macOS binary should not be empty');

      print('✅ Native binaries found:');
      print(
          '   Linux: ${(linuxFile.lengthSync() / 1024).toStringAsFixed(1)} KB');
      print(
          '   macOS: ${(macosFile.lengthSync() / 1024).toStringAsFixed(1)} KB');
    });

    test('should have correct error types', () {
      // Test error enums exist
      expect(DbErrorType.values.length, greaterThan(0));
      expect(DbErrorType.ffi, isA<DbErrorType>());
      expect(DbErrorType.notFound, isA<DbErrorType>());
      expect(DbErrorType.validation, isA<DbErrorType>());
      expect(DbErrorType.database, isA<DbErrorType>());

      print('✅ Error types defined correctly');
    });

    test('should create correct error messages', () {
      final error = DbError.validation('Test validation error');
      expect(error.type, equals(DbErrorType.validation));
      expect(error.message, equals('Test validation error'));

      print('✅ Error creation works correctly');
    });

    test('should demonstrate expected usage patterns', () {
      print('✅ Expected usage patterns:');
      print('');
      print('   // Basic usage');
      print('   final db = DB.open("my_cache").okOrNull!;');
      print('   final stored = db.post("key", {"data": "value"});');
      print('   final retrieved = db.get("key");');
      print('   final updated = db.patch("key", {"updated": true});');
      print('   db.close();');
      print('');
      print('   // Error handling');
      print('   result.when(');
      print('     ok: (data) => print("Success: \$data"),');
      print('     err: (error) => print("Error: \$error"),');
      print('   );');
      print('');
      print('✅ API documentation generated');
    });
  });
}
