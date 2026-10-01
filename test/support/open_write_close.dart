/// A whole program on dart_db: opens the database at the path of its
/// argument, writes, reads and closes. It must end by itself, as a CLI or a
/// migration script does.
library;

import 'dart:io';

import 'package:dart_db/dart_db.dart';

Future<void> main(List<String> args) async {
  final notes = DbTable<Note>('notes', key: 'id', fromJson: Note.fromJson);

  final outcome = await DartDb.open(args.first, tables: [notes]).flatMap(
    (db) => notes
        .insert(const [Note('a', 'written by a script')])
        .flatMap((_) => notes.all().count())
        .flatMap((count) => db.close().map((_) => count)),
  );

  exitCode = outcome.when(ok: (count) => count == 1 ? 0 : 2, err: (_) => 1);
}

/// A note.
final class Note {
  const Note(this.id, this.text);

  factory Note.fromJson(Map<String, dynamic> json) =>
      Note(json['id'] as String, json['text'] as String);

  final String id;
  final String text;

  Map<String, dynamic> toJson() => {'id': id, 'text': text};
}
