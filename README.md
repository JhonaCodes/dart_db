# dart_db

An embedded database for Dart servers and CLIs that stores the models your
code already has. Tables, secondary indexes, a query planner, joins,
aggregates and transactions with the query language of
[db_dsl](https://pub.dev/packages/db_dsl) (modelled on
[Diesel](https://diesel.rs)), on the Rust engine
[offline_first_core](https://github.com/JhonaCodes/offline_first_core) and
**LMDB 1.0.2**. No database server to run: the data lives in a directory next
to your service.

```dart
final opened = await DartDb.open('/var/lib/notes/data');

final notes = Note.table;
await notes.insert([Note(1, 'ada', 'Typed tables')]);
final byAda = await notes.filter(notes.author.eq('ada'));
```

- **Your models, as they are**: a model carries its table in one line
  (`static final table = DbTable<Note>(...)`), next to its `fromJson` and
  `toJson`. No table classes, no code generation, no macros.
- **Nothing to register**: `DartDb.open(path)` takes no list of tables;
  each defines itself the first time it is used.
- **Typed fields, written for you**: `notes.author` comes from an extension
  that the [db_dsl_lints](https://pub.dev/packages/db_dsl_lints) analyzer
  plugin writes from the model and checks in `dart analyze`.
- **Queries run when awaited**, on the database of the table or on the
  transaction around them.
- **Every call answers a `Result`** (`Ok` or `Err` with a typed `DbError`).
- **Request handlers never block on the disk**: every call runs on a
  database isolate, and concurrent handlers share one database (writes
  queue, reads run).

## Install

```yaml
dependencies:
  dart_db: ^0.3.0
```

Dart 3.10 or later. A build hook bundles the native library of the build
target (Linux, macOS and Windows, on x64 and arm64): `dart run`, `dart test`
and `dart build cli` work with nothing to configure.

## Open and query

```dart
Future<void> main() async {
  final opened = await DartDb.open('data/app');

  switch (opened) {
    case Ok():
      // Tables define themselves here on first use; queries run on it when
      // awaited.
      final users = User.table;
      final lima = await users.filter(users.city.eq('Lima'));
    case Err(:final error):
      stderr.writeln('Cannot open the database: $error');
      exitCode = 1;
  }
}
```

`DartDb.open` opens (or creates) `<path>.lmdb`. The first database a
process opens is the default one: a table defines itself there the first
time it is used — new ones are created, new indexes are built over existing
rows, removed indexes are dropped. A table first used inside a transaction
answers `DbErrorCode.tableNotReady`; `DartDb.open(path, tables: [...])`
defines tables up front for that case, and builds their indexes at
start-up. Open each path once per process and share the database across
handlers.

Everything about tables, fields, queries, writes, transactions, joins,
aggregates and errors is the API of db_dsl: see its
[README](https://pub.dev/packages/db_dsl), and
[db_dsl_lints](https://pub.dev/packages/db_dsl_lints) for the plugin that
writes and checks the typed fields (`plugins: db_dsl_lints: ^0.1.0` in
`analysis_options.yaml`).

## A small HTTP API

[`example/server.dart`](example/server.dart) serves `GET /notes?author=ada`
and `POST /notes` with `dart:io` and dart_db; a duplicate id answers `409`
from the `ConstraintError` of the insert.

```sh
dart run example/server.dart
```

## Offline-first sync

`DartDb` is a db_dsl `Database`, so `db.sync` and tables declared with
`syncWith` work here too: a server process that keeps a local replica of
another service gets the same outbox written in the same commit as each
row, acknowledged by mutation and revision, with conflicts kept instead of
overwritten. The rules and every operation are in db_dsl's
[PROTOCOL.md](https://github.com/JhonaCodes/db_dsl/blob/main/PROTOCOL.md)
("Sync"), and the conformance suite checks them on this engine.

```dart
static final table = DbTable<Note>('notes', key: 'id', fromJson: Note.fromJson, syncWith: 'upstream');

final batch = await db.sync.claim('upstream');      // leased envelopes to send
```

## Deploy

```sh
dart build cli -t example/server.dart -o build/server
./build/server/bundle/bin/server
```

`dart build cli` compiles the server ahead of time and places the native
library in `bundle/lib/`, next to the executable: copy the whole `bundle/`
directory. A program that closes its databases ends by itself, so CLIs and
migration scripts need no `exit()`.

| Platform | Architectures | Minimum |
|---|---|---|
| Linux | x64, arm64 | glibc 2.35 (Debian 12, Ubuntu 22.04) |
| macOS | x64, arm64 | macOS 10.15 |
| Windows | x64, arm64 | Windows 10 |

In Docker, use a glibc base image (such as `debian:bookworm-slim`), not
Alpine (musl), and keep the database directory on a volume.

## How it works

```
request handlers ── await notes.filter(…) ──► db_dsl: JSON request (protocol v1)
                                                   │
                                                   ▼
                                db_dsl's worker isolate (one per isolate that uses it)
                                                   │  dart:ffi (@Native)
                                                   ▼
                                offline_first_core (Rust): planner, indexes,
                                transactions
                                                   │
                                                   ▼
                                LMDB 1.0.2: <path>.lmdb
```

- `DartDb` is a db_dsl `Database` on the bundled engine: everything db_dsl
  documents applies as is.
- **The native library comes with the package.** `hook/build.dart` picks
  `native/<os>/<architecture>/` for the build target. `dart run` and
  `dart test` link it into `.dart_tool/lib`; `dart build cli` copies it to
  `bundle/lib/`, next to the executable. The bindings are entry points, so
  an ahead-of-time build keeps them.
- **Concurrent handlers share one database.** Writes queue in Dart (one
  writer at a time); reads are not queued behind them. Every native call
  runs on a worker isolate, so a handler never blocks on the disk.
- **Several isolates can open the same path.** Each gets a worker isolate
  of its own, and all of them share the process's one LMDB environment, so
  they see each other's commits.
- **A program ends by itself** once its databases are closed: the worker
  isolate stops with the last one.

## Using it well

- **Open each path once, at start-up, and share the `DartDb`** across
  handlers; close it when the process stops.
- **Deploy a `dart build cli` bundle**: copy the whole `bundle/` directory,
  on a glibc system for Linux.
- **One transaction per request that writes several rows**: a durable
  commit flushes the disk.
- **Index what you filter and order by**, and check it with `explain()`.
- **Use a table once before its first transaction**, or list it in
  `DartDb.open(path, tables: [...])`.
- **Enable db_dsl_lints and run `dart analyze` in CI**, so the typed fields
  stay in step with the models.
- **On Windows, do not start two `dart run` of the same project at once**:
  each one replaces the library in `.dart_tool/lib` while the other has it
  loaded ([dart-lang/sdk#63933](https://github.com/dart-lang/sdk/issues/63933)).
  Compiled bundles run side by side.

## Durability

```dart
await DartDb.open('data/app', options: const DbOptions(durability: Durability.noMetaSync));
```

`full` (default) flushes data and metadata on every commit; `noMetaSync`
flushes once and may undo the last transaction after a power loss, never
corrupting the database; `noSync` leaves flushing to the operating system.
The file grows as needed up to `maxSize` (16 GiB by default).

## Benchmarks

Measured from Dart in a `dart build cli` bundle: 10 000 rows with an index
on `(city, age)`, median of 3 rounds, on an Apple M1 Max, macOS 26.7, Dart
3.13.4. Rows are grouped by what a commit guarantees.

| Engine | Durability | Runs on | Insert 10k rows, 1 transaction (per row) | Insert, 1 transaction per row | Find by primary key | Find by primary key, 4 isolates at once | Indexed query, limit 50 | Indexed count | Update by key |
|---|---|---|---|---|---|---|---|---|---|
| dart_db 0.3 (full) | data and metadata flushed per commit | database isolate | 6.0 µs | 9.09 ms | 18.4 µs | 14.4 µs | 83.0 µs | 47.5 µs | 9.05 ms |
| SQLite 3.53.4 (synchronous=FULL) | WAL flushed per commit (fullfsync on Apple) | calling isolate | 2.3 µs | 4.79 ms | 2.9 µs | 1.8 µs | 37.0 µs | 48.7 µs | 4.93 ms |
| dart_db 0.3 (no_meta_sync) | data flushed per commit | database isolate | 5.9 µs | 4.67 ms | 17.8 µs | 15.9 µs | 80.3 µs | 46.3 µs | 5.16 ms |
| dart_db 0.3 (no_sync) | no flush per commit | database isolate | 5.1 µs | 39.2 µs | 17.9 µs | 14.2 µs | 82.4 µs | 48.7 µs | 43.4 µs |
| SQLite 3.53.4 (synchronous=OFF) | no flush per commit (WAL) | calling isolate | 1.6 µs | 25.0 µs | 3.0 µs | 1.6 µs | 35.9 µs | 47.7 µs | 25.2 µs |
| Hive CE 2 | no flush per write | calling isolate | 2.3 µs | 20.1 µs | 0.3 µs | n/a | 16.5 µs | 467.5 µs | 22.5 µs |
| Sembast 3 | no flush per write | calling isolate | 21.1 µs | 87.4 µs | 1.1 µs | n/a | 60.4 µs | 1.24 ms | 102.0 µs |

How to read it:

- **Every dart_db call crosses to its worker isolate**, which costs a round
  trip of about 15 µs: a lookup by key is slower than SQLite on the calling
  isolate, and in exchange a slow query or a durable commit never blocks
  the isolate that serves the request.
- **A durable commit is about twice SQLite's**: LMDB flushes the data and
  then the metadata page. `noMetaSync` flushes once and matches it.
- **Reads from several isolates do not scale linearly yet**: 4 isolates
  reading at once take 14 µs per lookup against 18 µs from one.
- Hive CE and Sembast keep every row in memory: lookups are fast, and
  counts scan every row.

Reproduce with the commands in [benchmark/README.md](benchmark/README.md).

## Migrating from 0.2

0.3 replaces the key-value `DB` of 0.2 with tables, and stores data with
LMDB 1.0, which cannot read the files of 0.2 (LMDB 0.9): opening one answers
`Err` with `DbErrorCode.legacyFormat` and leaves it untouched.

1. With 0.2, export every record (`db.all()`) to a JSON file.
2. With 0.3, insert the records into a table:

```dart
final class Record {
  const Record(this.key, this.data);

  factory Record.fromJson(Map<String, dynamic> json) =>
      Record(json['key'] as String, json['data'] as Map<String, dynamic>);

  final String key;
  final Map<String, dynamic> data;

  Map<String, dynamic> toJson() => {'key': key, 'data': data};
}

final records = DbTable<Record>('records', key: 'key', fromJson: Record.fromJson);

final exported = jsonDecode(await File('export.json').readAsString()) as Map<String, dynamic>;
await records.insert([
  for (final MapEntry(:key, :value) in exported.entries)
    Record(key, value as Map<String, dynamic>),
]);
```

## License

MIT. See [LICENSE](LICENSE).
