@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

/// A program that closes its databases ends: the worker isolate of the
/// native engine does not keep it alive.
void main() {
  test(
    'a program that opens, writes and closes its database ends by itself',
    () async {
      final directory = await Directory.systemTemp.createTemp('dart_db_exit');
      addTearDown(() => directory.delete(recursive: true));

      final process = await Process.start(Platform.resolvedExecutable, [
        'run',
        'test/support/open_write_close.dart',
        '${directory.path}/app',
      ]);
      final output = StringBuffer();
      process.stdout.transform(utf8.decoder).listen(output.write);
      process.stderr.transform(utf8.decoder).listen(output.write);

      final code = await process.exitCode.timeout(
        const Duration(seconds: 120),
        onTimeout: () {
          process.kill();
          return -1;
        },
      );

      expect(code, 0, reason: 'exit code (-1: still running). $output');
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
