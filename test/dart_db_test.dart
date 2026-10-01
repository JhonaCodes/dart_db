import 'dart:io';
import 'dart:isolate';

import 'package:dart_db/dart_db.dart';
import 'package:test/test.dart';

/// What only the bundled engine does: its storage, its planner, concurrent
/// handlers on one database.
void main() {
  late Directory directory;
  final notes = DbTable<Note>(
    'notes',
    key: 'id',
    fromJson: Note.fromJson,
    indexes: [
      Index(['author', 'year']),
    ],
  );
  final author = notes.field<String>('author');
  final year = notes.field<int>('year');

  setUp(
    () async => directory = await Directory.systemTemp.createTemp('dart_db'),
  );
  tearDown(() => directory.delete(recursive: true));

  Future<DartDb> open() async =>
      value(await DartDb.open('${directory.path}/app', tables: [notes]));

  test('a table defines itself on a database opened without it', () async {
    final db = value(await DartDb.open('${directory.path}/app'));

    expect(value(await notes.insert([Note(1, 'ada', 2021)])), 1);
    expect(value(await db.tables()).map((table) => table.name), ['notes']);
    await db.close();

    final reopened = value(await DartDb.open('${directory.path}/app'));
    expect(value(await notes.all().count()), 1);
    await reopened.close();
  });

  test('info reports LMDB 1.0.2', () async {
    final db = await open();

    expect(value(await db.info()).storage, '1.0.2');
    await db.close();
  });

  test('the planner uses the declared index', () async {
    final db = await open();
    final plan = value(
      await notes
          .filter(author.eq('ada').and(year.ge(2020)))
          .order(year.desc())
          .explain(),
    );

    expect(plan.access, PlanAccess.indexScan);
    expect(plan.index, 'by_author_year');
    expect(plan.exact, isTrue);
    await db.close();
  });

  test('isolates of one process share the database', () async {
    final db = await open();
    final path = '${directory.path}/app';

    // Each isolate opens the same path on its own native worker, and they
    // write at the same time.
    final written = await Future.wait([
      for (var worker = 0; worker < 3; worker++)
        Isolate.run(() => IsolateWriter.write(path, worker)),
    ]);

    expect(written, [100, 100, 100]);
    expect(value(await notes.all().count()), 300, reason: 'seen here too');
    expect(value(await notes.filter(author.eq('author-2')).count()), 100);
    await db.close();
  });

  test('a relation reads only the neighbours of a row', () async {
    final db = await open();
    final related = Relation<Note, Note>('related', from: notes, to: notes);
    value(
      await notes.insert([for (var i = 0; i < 50; i++) Note(i, 'a', 2000)]),
    );
    value(
      await related.attach(const Note(1, 'a', 2000), const Note(7, 'a', 2000)),
    );
    value(
      await related.attach(const Note(1, 'a', 2000), const Note(3, 'a', 2000)),
    );

    expect(
      value(await related.targetsOf(const Note(1, 'a', 2000))).map((n) => n.id),
      [3, 7],
    );

    // The two reads of `targetsOf`: an index range on the bridge, then
    // primary key lookups, never a full scan.
    final links = value(
      await related.links
          .filter(related.links.field<Object>('from').eq(1))
          .explain(),
    );
    expect((links.access, links.index), (PlanAccess.indexScan, 'by_from'));
    final rows = value(
      await notes.filter(notes.primaryKey.eqAny([3, 7])).explain(),
    );
    expect(rows.access, PlanAccess.primaryKeyLookup);
    await db.close();
  });

  test('concurrent handlers share one database', () async {
    final db = await open();

    // A server answers many requests at once: writes queue, reads run.
    final writes = Future.wait([
      for (var i = 0; i < 50; i++)
        notes.insert([Note(i, 'author-${i % 5}', 2000 + i)]),
    ]);
    final reads = Future.wait([
      for (var i = 0; i < 50; i++) notes.all().count(),
    ]);

    expect((await writes).map(value), everyElement(1));
    expect((await reads).map(value), everyElement(inInclusiveRange(0, 50)));
    expect(value(await notes.all().count()), 50);
    await db.close();
  });
}

/// What one isolate of [IsolateWriter.write] does: opens the database at a
/// path on its own and writes notes of its own.
abstract final class IsolateWriter {
  /// Opens [path], writes 100 notes with ids `worker * 1000 + i`, one
  /// statement each, closes it and answers how many were written.
  static Future<int> write(String path, int worker) async {
    // A table of its own, defined as the main isolate defines it: statics
    // and objects are per isolate.
    final notes = DbTable<Note>(
      'notes',
      key: 'id',
      fromJson: Note.fromJson,
      indexes: [
        Index(['author', 'year']),
      ],
    );
    final db = value(await DartDb.open(path, tables: [notes]));
    var written = 0;

    for (var i = 0; i < 100; i++) {
      written += value(
        await notes.insert([Note(worker * 1000 + i, 'author-$worker', 2000)]),
      );
    }

    value(await db.close());
    return written;
  }
}

/// The value of an `Ok`; fails the test on an `Err`.
T value<T>(Result<T, DbError> result) =>
    result.when(ok: (data) => data, err: (error) => fail('Err: $error'));

/// A note, as an app models it.
final class Note {
  const Note(this.id, this.author, this.year);

  factory Note.fromJson(Map<String, dynamic> json) =>
      Note(json['id'] as int, json['author'] as String, json['year'] as int);

  final int id;
  final String author;
  final int year;

  Map<String, dynamic> toJson() => {'id': id, 'author': author, 'year': year};
}
