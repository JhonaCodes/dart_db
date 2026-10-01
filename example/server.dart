/// A small HTTP API on dart_db: `GET /notes?author=ada` lists notes, `POST
/// /notes` with `{"id": 1, "author": "ada", "text": "..."}` stores one.
///
/// Run it with `dart run example/server.dart`, or deploy it:
///
/// ```sh
/// dart build cli -t example/server.dart -o build/server
/// ./build/server/bundle/bin/server
/// ```
library;

import 'dart:convert';
import 'dart:io';

import 'package:dart_db/dart_db.dart';

Future<void> main(List<String> args) async {
  final path = args.isEmpty ? '${Directory.systemTemp.path}/notes' : args.first;
  final opened = await DartDb.open(path);

  switch (opened) {
    case Ok():
      // No table is listed: `notes` defines itself on this database the
      // first time a route uses it, and the routes never name it.
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8080);
      stdout.writeln('Listening on http://localhost:8080/notes ($path.lmdb)');
      await server.forEach(const NotesApi().handle);
    case Err(:final error):
      stderr.writeln('Cannot open the database: $error');
      exitCode = 1;
  }
}

/// The routes of the example.
final class NotesApi {
  /// The API over the open database.
  const NotesApi();

  static final DbTable<Note> _notes = Note.table;

  /// Answers one request.
  Future<void> handle(HttpRequest request) async {
    final (status, body) = switch ((request.method, request.uri.path)) {
      ('GET', '/notes') => await _list(request.uri.queryParameters['author']),
      ('POST', '/notes') => await _create(await utf8.decodeStream(request)),
      _ => (HttpStatus.notFound, {'error': 'not found'}),
    };

    request.response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
    await request.response.close();
  }

  Future<(int, Object)> _list(String? author) async {
    final query = switch (author) {
      null => _notes.all(),
      final String name => _notes.filter(_notes.author.eq(name)),
    };

    return (await query.order(_notes.id.asc())).when(
      ok: (rows) => (HttpStatus.ok, [for (final note in rows) note.toJson()]),
      err: (error) => (HttpStatus.internalServerError, {'error': '$error'}),
    );
  }

  Future<(int, Object)> _create(String body) async {
    final Note note;

    try {
      note = Note.fromJson(jsonDecode(body) as Map<String, Object?>);
    } on Object catch (error) {
      return (HttpStatus.badRequest, {'error': 'Invalid note: $error'});
    }

    return (await _notes.insert([note])).when(
      ok: (_) => (HttpStatus.created, note.toJson()),
      err: (error) => switch (error) {
        ConstraintError() => (HttpStatus.conflict, {'error': error.message}),
        _ => (HttpStatus.internalServerError, {'error': '$error'}),
      },
    );
  }
}

/// A note: a plain model that carries its table.
final class Note {
  /// A note [id] by [author].
  const Note({required this.id, required this.author, required this.text});

  /// The note stored as [json].
  factory Note.fromJson(Map<String, Object?> json) => Note(
    id: json['id']! as int,
    author: json['author']! as String,
    text: json['text']! as String,
  );

  /// The `notes` table, indexed by author.
  static final DbTable<Note> table = DbTable<Note>(
    'notes',
    key: 'id',
    fromJson: Note.fromJson,
    indexes: [
      Index(['author']),
    ],
  );

  /// Primary key.
  final int id;

  /// Who wrote it.
  final String author;

  /// The content.
  final String text;

  /// The stored form.
  Map<String, Object?> toJson() => {'id': id, 'author': author, 'text': text};
}

// Written by the quick fix "Write the query fields from the model" of the
// db_dsl_lints analyzer plugin, not by hand.

/// The fields of `Note` for queries, read from its `toJson`.
extension NoteFields on DbTable<Note> {
  /// The stored `id`.
  Field<int> get id => field('id');

  /// The stored `author`.
  Field<String> get author => field('author');

  /// The stored `text`.
  Field<String> get text => field('text');
}
