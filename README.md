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
                                db_dsl's worker isolate (one per process)
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
  runs on one worker isolate, so a handler never blocks on the disk.
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
