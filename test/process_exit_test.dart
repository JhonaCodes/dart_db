@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

/// A program that closes its databases ends: the worker isolate of the
/// native engine does not keep it alive.
///
/// The program is compiled with `dart build cli`, as a CLI is deployed, and
/// run from its bundle. Why not `dart run`: it relinks the native library in
/// `.dart_tool/lib`, which this test process has loaded, and Windows refuses
/// to replace a loaded library.
void main() {
  test(
    'a program that opens, writes and closes its database ends by itself',
    () async {
      final directory = await Directory.systemTemp.createTemp('dart_db_exit');
      addTearDown(() => directory.delete(recursive: true));

      final executable = await Bundle.build(
        'test/support/open_write_close.dart',
        directory,
      );

      final process = await Process.start(executable, [
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

  test(
    'a bundle that only takes the addresses of the bindings resolves them',
    () async {
      final directory = await Directory.systemTemp.createTemp('dart_db_aot');
      addTearDown(() => directory.delete(recursive: true));

      final executable = await Bundle.build(
        'test/support/symbols_only.dart',
        directory,
      );
      final run = await Process.run(executable, const []);

      // Four non-zero addresses, not "Couldn't resolve native function".
      expect(run.exitCode, 0, reason: '${run.stdout}${run.stderr}');
      expect(
        (run.stdout as String).trim().split(' ').map(int.parse),
        everyElement(isNot(0)),
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

/// A support program compiled with `dart build cli`, as a CLI is deployed.
abstract final class Bundle {
  /// Compiles [target] into [directory] and answers its executable.
  static Future<String> build(String target, Directory directory) async {
    final build = await Process.run(Platform.resolvedExecutable, [
      'build',
      'cli',
      '-t',
      target,
      '-o',
      '${directory.path}/build',
    ]);
    expect(build.exitCode, 0, reason: '${build.stdout}${build.stderr}');

    // One executable: `<name>`, or `<name>.exe` on Windows.
    return Directory(
      '${directory.path}/build/bundle/bin',
    ).listSync().single.path;
  }
}
