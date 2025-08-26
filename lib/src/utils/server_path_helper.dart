import 'dart:io';
import 'package:path/path.dart' as path;
import '../models/db_result.dart';
import '../models/db_error.dart';

/// Simplified path management for server databases
class ServerPathHelper {
  static const String defaultDatabaseName = 'database.lmdb';
  static const String defaultSubdirectory = 'data';

  /// Gets the default database path for server applications
  ///
  /// Simple approach using standard conventions:
  /// - **Linux/macOS**: `$HOME/.local/share/dart_db/database.lmdb`
  /// - **Windows**: `%APPDATA%/dart_db/database.lmdb`
  /// - **Fallback**: `./data/dart_db/database.lmdb`
  static DbResult<String, DbError> getDefaultDatabasePath() {
    try {
      String baseDir;

      final home = Platform.environment['HOME'];
      final appData = Platform.environment['APPDATA'];

      if (Platform.isWindows && appData != null) {
        baseDir = path.join(appData, 'dart_db');
      } else if (home != null) {
        baseDir = path.join(home, '.local', 'share', 'dart_db');
      } else {
        baseDir =
            path.join(Directory.current.path, defaultSubdirectory, 'dart_db');
      }

      final dbPath = path.join(baseDir, defaultDatabaseName);
      return Ok(dbPath);
    } catch (e) {
      return Err(
          DbError.platform('Failed to determine database path', cause: e));
    }
  }

  /// Ensures the directory for the database path exists
  static DbResult<void, DbError> ensureDirectoryExists(String databasePath) {
    try {
      final directory = path.dirname(databasePath);
      final dir = Directory(directory);

      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      return const Ok(null);
    } catch (e) {
      return Err(DbError.platform('Failed to create directory', cause: e));
    }
  }
}
