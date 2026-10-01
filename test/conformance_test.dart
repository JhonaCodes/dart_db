import 'dart:io';

import 'package:dart_db/src/native/offline_first_core.dart';
import 'package:db_dsl/conformance.dart';
import 'package:test/test.dart';

/// The conformance suite of db_dsl against the offline_first_core bundled by
/// dart_db: the server engine must behave exactly like the protocol.
void main() {
  late Directory root;
  var next = 0;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('dart_db_conformance');
  });
  tearDownAll(() => root.delete(recursive: true));

  final host = ConformanceHost(
    OfflineFirstCore.engine,
    () async => '${root.path}/db-${next++}',
  );

  for (final ConformanceCase(:group, :name, :run) in Conformance.cases) {
    test('$group: $name', () => run(host));
  }
}
