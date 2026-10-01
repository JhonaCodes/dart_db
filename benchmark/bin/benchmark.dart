import 'dart:io';

import 'package:dart_db_benchmark/benchmark.dart';

/// Runs the server benchmark and prints its table; the table is also saved
/// to `build/benchmark.md`.
///
/// ```sh
/// dart build cli -t bin/benchmark.dart -o build/cli
/// build/cli/bundle/bin/benchmark
/// ```
Future<void> main() async {
  final root = await Directory.systemTemp.createTemp('dart_db_benchmark');
  final results = await Benchmark.run(
    root,
    progress: (result) => stdout.writeln('${result.engine}: done'),
  );
  await root.delete(recursive: true);

  final table = Benchmark.markdown(results);
  await Directory('build').create();
  await File('build/benchmark.md').writeAsString('$table\n');
  stdout.writeln(table);
}
