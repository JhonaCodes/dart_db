/// dart_db: the db_dsl query language on the offline_first_core engine
/// (Rust + LMDB 1.0), for Dart servers on Linux, macOS and Windows.
///
/// Everything of db_dsl is exported: tables, columns, expressions, queries,
/// transactions, `Result` with `Ok` and `Err`, and [DbError].
library;

export 'package:db_dsl/db_dsl.dart';

export 'src/dart_db.dart';
