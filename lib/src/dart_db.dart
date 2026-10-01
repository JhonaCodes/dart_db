/// The database of dart_db: a db_dsl [Database] on the bundled
/// offline_first_core.
library;

import 'package:db_dsl/db_dsl.dart';

import 'native/offline_first_core.dart';

/// An embedded database for Dart servers, queried Diesel-style.
///
/// ```dart
/// final opened = await DartDb.open('/var/lib/app/data');
///
/// // Tables define themselves here on first use: awaiting a query runs it
/// // here.
/// final users = User.table;
/// final adults = await users.filter(users.age.ge(18));
/// ```
///
/// Tables, queries, transactions and `watch` come from db_dsl and answer a
/// `Result`. Files live in `<path>.lmdb`. Every call runs on a worker
/// isolate, so request handlers never block on the disk; open one [DartDb]
/// per path and share it across handlers.
///
/// Why a subclass: servers open it without choosing an engine; the bundled
/// one is the engine of dart_db.
final class DartDb extends Database {
  DartDb._(super.connection, super.path) : super.connected();

  /// Opens (or creates) the database at `<path>.lmdb`.
  ///
  /// Tables need not be listed: the first database opened is the default
  /// one, and a table defines itself there the first time it is used.
  /// [tables] defines them up front (adding or removing indexes of
  /// existing ones), for a table first used inside a transaction (which
  /// answers [DbErrorCode.tableNotReady] otherwise) or to build indexes at
  /// start-up.
  ///
  /// [DbErrorCode.legacyFormat] means the files were written by dart_db 0.2
  /// (LMDB 0.9), which this version cannot read.
  static Future<Result<DartDb, DbError>> open(
    String path, {
    List<DbTable<Object?>> tables = const [],
    DbOptions options = const DbOptions(),
  }) async => (await OfflineFirstCore.engine.open(path, options)).when(
    ok: (connection) async {
      final database = DartDb._(connection, path);
      return (await database.defineTables(tables)).map((_) => database);
    },
    err: (error) async => Err(error),
  );
}
