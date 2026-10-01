# dart_db example

[`server.dart`](server.dart) is a small HTTP API on dart_db:

- `GET /notes?author=ada` lists the notes of an author, through an index;
- `POST /notes` with `{"id": 1, "author": "ada", "text": "..."}` stores one,
  and a duplicate id answers `409` from the `ConstraintError` of the insert.

The `Note` model is a plain class with `fromJson` and `toJson` that carries
its table:

```dart
static final DbTable<Note> table = DbTable<Note>(
  'notes',
  key: 'id',
  fromJson: Note.fromJson,
  indexes: [Index(['author'])],
);
```

`DartDb.open(path)` lists no table: `notes` defines itself on its first use.
The routes query `Note.table.author.eq(name)` through `NoteFields`, the
extension the [db_dsl_lints](https://pub.dev/packages/db_dsl_lints) analyzer
plugin writes from the model.

Run it, or compile it ahead of time with the native library bundled:

```sh
dart run example/server.dart
dart build cli -t example/server.dart -o build/server
./build/server/bundle/bin/server
```
