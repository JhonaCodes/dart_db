/// The engines under benchmark, each storing the same rows.
library;

import 'dart:isolate';

import 'package:dart_db/dart_db.dart';
import 'package:hive_ce/hive.dart';
import 'package:sembast/sembast_io.dart' as sembast;
import 'package:sqlite3/sqlite3.dart' as sql;

/// A database under benchmark. Every engine stores the same rows and answers
/// the same operations; see `Benchmark`.
abstract interface class BenchmarkEngine {
  /// Name shown in the results.
  String get name;

  /// When a committed write reaches the disk.
  String get durability;

  /// Where the database work runs: the calling isolate (blocking it) or
  /// another thread.
  String get runsOn;

  /// Opens a fresh database inside [directory].
  Future<void> open(String directory);

  /// Inserts [rows] in one transaction.
  Future<void> insertBatch(List<Map<String, Object?>> rows);

  /// Inserts one row in its own transaction.
  Future<void> insertOne(Map<String, Object?> row);

  /// The row with primary key [id].
  Future<Map<String, Object?>?> find(int id);

  /// Up to [limit] rows with `city = city AND age > minAge`.
  Future<int> query(String city, int minAge, int limit);

  /// Number of rows with `city = city`.
  Future<int> count(String city);

  /// Sets `age` of the row [id], in its own transaction.
  Future<void> updateAge(int id, int age);

  /// Looks up `ids` by primary key from [isolates] isolates at once, each
  /// with a connection of its own to the open database; `null` when the
  /// engine cannot share its file between isolates.
  Future<IsolateReads?> findFromIsolates(int isolates, List<int> ids);

  /// Closes the database.
  Future<void> close();
}

/// What the isolates of `findFromIsolates` did: the rows they found, and
/// when the first lookup started and the last one ended (wall clock, shared
/// by every isolate), so opening the connections is not measured.
final class IsolateReads {
  /// The reads of [loops], one `(rows, start, end)` per isolate.
  IsolateReads(List<(int, int, int)> loops)
    : rows = loops.fold(0, (sum, loop) => sum + loop.$1),
      microseconds =
          loops.map((loop) => loop.$3).reduce(_max) -
          loops.map((loop) => loop.$2).reduce(_min);

  /// Rows found by every isolate.
  final int rows;

  /// From the first lookup to the last, in microseconds.
  final int microseconds;

  static int _max(int a, int b) => a > b ? a : b;
  static int _min(int a, int b) => a < b ? a : b;

  /// Now, in microseconds of the wall clock.
  static int get now => DateTime.now().microsecondsSinceEpoch;
}

/// A row of the `users` table of dart_db: the benchmark keeps rows as plain
/// JSON, and its serializer is the JSON itself, passed as `toJson`.
final class UserRow {
  /// Wraps the stored JSON.
  const UserRow(this.json);

  /// The stored JSON.
  final Map<String, Object?> json;
}

/// dart_db 0.3 as a server uses it: one `DartDb.open`, then awaited queries.
final class DartDbEngine implements BenchmarkEngine {
  /// Opens with [mode].
  DartDbEngine(this.mode);

  /// Durability of the commits.
  final Durability mode;

  late DartDb _db;
  late String _path;

  /// The `users` table, with the index the query and the count use.
  static DbTable<UserRow> get _users => DbTable<UserRow>(
    'users',
    key: 'id',
    fromJson: UserRow.new,
    toJson: (row) => row.json,
    indexes: [
      Index(['city', 'age']),
    ],
  );

  late final DbTable<UserRow> _table = _users;
  late final Field<int> _id = _table.field<int>('id');
  late final Field<String> _city = _table.field<String>('city');
  late final Field<int> _age = _table.field<int>('age');

  @override
  String get name => 'dart_db 0.3 (${mode.wire})';

  @override
  String get durability => switch (mode) {
    Durability.full => 'data and metadata flushed per commit',
    Durability.noMetaSync => 'data flushed per commit',
    Durability.noSync => 'no flush per commit',
  };

  @override
  String get runsOn => 'database isolate';

  @override
  Future<void> open(String directory) async {
    _path = '$directory/dart_db';
    _db = _ok(
      await DartDb.open(
        _path,
        tables: [_table],
        options: DbOptions(durability: mode),
      ),
    );
  }

  @override
  Future<void> insertBatch(List<Map<String, Object?>> rows) async =>
      _ok(await _table.insert([for (final row in rows) UserRow(row)]));

  @override
  Future<void> insertOne(Map<String, Object?> row) async =>
      _ok(await _table.insert([UserRow(row)]));

  @override
  Future<Map<String, Object?>?> find(int id) async =>
      _ok(await _table.find(id))?.json;

  @override
  Future<int> query(String city, int minAge, int limit) async => _ok(
    await _table.filter(_city.eq(city).and(_age.gt(minAge))).limit(limit),
  ).length;

  @override
  Future<int> count(String city) async =>
      _ok(await _table.filter(_city.eq(city)).count());

  @override
  Future<void> updateAge(int id, int age) async =>
      _ok(await _table.update().filter(_id.eq(id)).set(_age, age));

  @override
  Future<IsolateReads?> findFromIsolates(int isolates, List<int> ids) async {
    final path = _path;
    final mode = this.mode;
    final loops = await Future.wait([
      for (var i = 0; i < isolates; i++)
        Isolate.run(() async {
          // Each isolate opens the same path: it shares the environment of
          // the process through its own native worker.
          final users = _users;
          final db = _ok(
            await DartDb.open(
              path,
              tables: [users],
              options: DbOptions(durability: mode),
            ),
          );
          var rows = 0;
          final start = IsolateReads.now;
          for (final id in ids) {
            if (_ok(await users.find(id)) != null) {
              rows++;
            }
          }
          final end = IsolateReads.now;
          _ok(await db.close());
          return (rows, start, end);
        }),
    ]);
    return IsolateReads(loops);
  }

  @override
  Future<void> close() async => _ok(await _db.close());

  /// The value of [result]; in a benchmark an error is a failed run.
  static T _ok<T>(Result<T, DbError> result) => result.when(
    ok: (value) => value,
    err: (error) => throw StateError('dart_db: $error'),
  );
}

/// SQLite through `package:sqlite3`, with prepared statements and an index on
/// `(city, age)`.
final class SqliteEngine implements BenchmarkEngine {
  /// With [durable], every commit is flushed (`synchronous=FULL`, and
  /// `fullfsync` on Apple); otherwise flushing is left to the OS
  /// (`synchronous=OFF`).
  SqliteEngine({required this.durable});

  /// Whether commits are flushed.
  final bool durable;

  late sql.Database _db;
  late String _file;
  late sql.PreparedStatement _insert;
  late sql.PreparedStatement _find;
  late sql.PreparedStatement _query;
  late sql.PreparedStatement _count;
  late sql.PreparedStatement _update;

  @override
  String get name =>
      'SQLite ${sql.sqlite3.version.libVersion} '
      '(${durable ? 'synchronous=FULL' : 'synchronous=OFF'})';

  @override
  String get durability => durable
      ? 'WAL flushed per commit (fullfsync on Apple)'
      : 'no flush per commit (WAL)';

  @override
  String get runsOn => 'calling isolate';

  @override
  Future<void> open(String directory) async {
    _file = '$directory/sqlite.db';
    _db = sql.sqlite3.open(_file);
    _db.execute('PRAGMA journal_mode=WAL');
    _db.execute(
      durable
          ? 'PRAGMA synchronous=FULL; PRAGMA fullfsync=ON'
          : 'PRAGMA synchronous=OFF',
    );
    _db.execute(
      'CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, email TEXT, '
      'age INTEGER, city TEXT, active INTEGER)',
    );
    _db.execute('CREATE INDEX by_city_age ON users (city, age)');
    _insert = _db.prepare('INSERT INTO users VALUES (?, ?, ?, ?, ?, ?)');
    _find = _db.prepare('SELECT * FROM users WHERE id = ?');
    _query = _db.prepare(
      'SELECT * FROM users WHERE city = ? AND age > ? LIMIT ?',
    );
    _count = _db.prepare('SELECT COUNT(*) FROM users WHERE city = ?');
    _update = _db.prepare('UPDATE users SET age = ? WHERE id = ?');
  }

  List<Object?> _values(Map<String, Object?> row) => [
    row['id'],
    row['name'],
    row['email'],
    row['age'],
    row['city'],
    (row['active']! as bool) ? 1 : 0,
  ];

  @override
  Future<void> insertBatch(List<Map<String, Object?>> rows) async {
    _db.execute('BEGIN');
    for (final row in rows) {
      _insert.execute(_values(row));
    }
    _db.execute('COMMIT');
  }

  @override
  Future<void> insertOne(Map<String, Object?> row) async =>
      _insert.execute(_values(row));

  @override
  Future<Map<String, Object?>?> find(int id) async {
    final result = _find.select([id]);
    return result.isEmpty ? null : Map.of(result.first);
  }

  @override
  Future<int> query(String city, int minAge, int limit) async =>
      _query.select([city, minAge, limit]).length;

  @override
  Future<int> count(String city) async =>
      _count.select([city]).first.values.first! as int;

  @override
  Future<void> updateAge(int id, int age) async => _update.execute([age, id]);

  @override
  Future<IsolateReads?> findFromIsolates(int isolates, List<int> ids) async {
    final file = _file;
    final loops = await Future.wait([
      for (var i = 0; i < isolates; i++)
        Isolate.run(() {
          // A connection per isolate on the same WAL file.
          final db = sql.sqlite3.open(file);
          final find = db.prepare('SELECT * FROM users WHERE id = ?');
          var rows = 0;
          final start = IsolateReads.now;
          for (final id in ids) {
            if (find.select([id]).isNotEmpty) {
              rows++;
            }
          }
          final end = IsolateReads.now;
          find.close();
          db.close();
          return (rows, start, end);
        }),
    ]);
    return IsolateReads(loops);
  }

  @override
  Future<void> close() async {
    for (final statement in [_insert, _find, _query, _count, _update]) {
      statement.close();
    }
    _db.close();
  }
}

/// Hive CE: an in-memory index of keys over an append-only file. Queries scan
/// the values, since Hive has no secondary indexes.
final class HiveEngine implements BenchmarkEngine {
  late Box<Map<dynamic, dynamic>> _box;

  @override
  String get name => 'Hive CE 2';

  @override
  String get durability => 'no flush per write';

  @override
  String get runsOn => 'calling isolate';

  @override
  Future<void> open(String directory) async {
    Hive.init(directory);
    _box = await Hive.openBox<Map<dynamic, dynamic>>('users');
  }

  @override
  Future<void> insertBatch(List<Map<String, Object?>> rows) =>
      _box.putAll({for (final row in rows) row['id']! as int: row});

  @override
  Future<void> insertOne(Map<String, Object?> row) =>
      _box.put(row['id']! as int, row);

  @override
  Future<Map<String, Object?>?> find(int id) async =>
      _box.get(id)?.cast<String, Object?>();

  @override
  Future<int> query(String city, int minAge, int limit) async => _box.values
      .where((row) => row['city'] == city && (row['age']! as int) > minAge)
      .take(limit)
      .length;

  @override
  Future<int> count(String city) async =>
      _box.values.where((row) => row['city'] == city).length;

  @override
  Future<void> updateAge(int id, int age) {
    final row = Map<String, Object?>.from(_box.get(id)!);
    row['age'] = age;
    return _box.put(id, row);
  }

  /// A Hive box belongs to the isolate that opened it.
  @override
  Future<IsolateReads?> findFromIsolates(int isolates, List<int> ids) async =>
      null;

  @override
  Future<void> close() => Hive.close();
}

/// Sembast: every record in memory, persisted to an append-only file.
final class SembastEngine implements BenchmarkEngine {
  late sembast.Database _db;
  final sembast.StoreRef<int, Map<String, Object?>> _store = sembast
      .intMapStoreFactory
      .store('users');

  @override
  String get name => 'Sembast 3';

  @override
  String get durability => 'no flush per write';

  @override
  String get runsOn => 'calling isolate';

  @override
  Future<void> open(String directory) async {
    _db = await sembast.databaseFactoryIo.openDatabase('$directory/sembast.db');
  }

  @override
  Future<void> insertBatch(List<Map<String, Object?>> rows) =>
      _db.transaction((txn) async {
        for (final row in rows) {
          await _store.record(row['id']! as int).put(txn, row);
        }
      });

  @override
  Future<void> insertOne(Map<String, Object?> row) =>
      _store.record(row['id']! as int).put(_db, row);

  @override
  Future<Map<String, Object?>?> find(int id) => _store.record(id).get(_db);

  @override
  Future<int> query(String city, int minAge, int limit) async =>
      (await _store.find(
        _db,
        finder: sembast.Finder(
          filter: sembast.Filter.and([
            sembast.Filter.equals('city', city),
            sembast.Filter.greaterThan('age', minAge),
          ]),
          limit: limit,
        ),
      )).length;

  @override
  Future<int> count(String city) =>
      _store.count(_db, filter: sembast.Filter.equals('city', city));

  @override
  Future<void> updateAge(int id, int age) =>
      _store.record(id).update(_db, {'age': age});

  /// A Sembast database is loaded into the memory of one isolate.
  @override
  Future<IsolateReads?> findFromIsolates(int isolates, List<int> ids) async =>
      null;

  @override
  Future<void> close() => _db.close();
}
