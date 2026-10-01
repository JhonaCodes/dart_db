# dart_db server benchmark

The same rows and operations for dart_db, SQLite (`package:sqlite3`), Hive CE
and Sembast, compiled ahead of time with `dart build cli` as a server is
deployed: 10 000 rows (`id, name, email, age, city, active`) with an index
on `(city, age)`, each cell the median of 3 rounds.

```sh
dart pub get
dart build cli -t bin/benchmark.dart -o build/cli
build/cli/bundle/bin/benchmark   # prints the table and saves build/benchmark.md
```

"Find by primary key, 4 isolates at once" runs 2 000 lookups in each of 4
isolates, each with a connection of its own to the same file; the time is
from the first lookup to the last (opening the connections is not counted),
divided by every lookup. Hive CE and Sembast keep a database inside one
isolate, so it does not apply to them.

Results on an Apple M1 Max, macOS 26.7, Dart 3.13.4 (dart_db 0.3.1,
offline_first_core 0.7.0):

| Engine | Durability | Runs on | Insert 10k rows, 1 transaction (per row) | Insert, 1 transaction per row | Find by primary key | Find by primary key, 4 isolates at once | Indexed query, limit 50 | Indexed count | Update by key |
|---|---|---|---|---|---|---|---|---|---|
| dart_db 0.3 (full) | data and metadata flushed per commit | database isolate | 6.0 µs | 9.09 ms | 18.4 µs | 14.4 µs | 83.0 µs | 47.5 µs | 9.05 ms |
| SQLite 3.53.4 (synchronous=FULL) | WAL flushed per commit (fullfsync on Apple) | calling isolate | 2.3 µs | 4.79 ms | 2.9 µs | 1.8 µs | 37.0 µs | 48.7 µs | 4.93 ms |
| dart_db 0.3 (no_meta_sync) | data flushed per commit | database isolate | 5.9 µs | 4.67 ms | 17.8 µs | 15.9 µs | 80.3 µs | 46.3 µs | 5.16 ms |
| dart_db 0.3 (no_sync) | no flush per commit | database isolate | 5.1 µs | 39.2 µs | 17.9 µs | 14.2 µs | 82.4 µs | 48.7 µs | 43.4 µs |
| SQLite 3.53.4 (synchronous=OFF) | no flush per commit (WAL) | calling isolate | 1.6 µs | 25.0 µs | 3.0 µs | 1.6 µs | 35.9 µs | 47.7 µs | 25.2 µs |
| Hive CE 2 | no flush per write | calling isolate | 2.3 µs | 20.1 µs | 0.3 µs | n/a | 16.5 µs | 467.5 µs | 22.5 µs |
| Sembast 3 | no flush per write | calling isolate | 21.1 µs | 87.4 µs | 1.1 µs | n/a | 60.4 µs | 1.24 ms | 102.0 µs |
