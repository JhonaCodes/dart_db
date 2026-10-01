import 'dart:ffi';
import 'dart:io';

import 'package:dart_db/src/native/bindings.dart';
import 'package:dart_db/src/native/offline_first_core.dart';
import 'package:db_dsl/conformance.dart';
import 'package:db_dsl/db_dsl.dart';
import 'package:db_dsl/native.dart';
import 'package:test/test.dart';

/// The conformance suite of db_dsl against the offline_first_core bundled by
/// dart_db, through both C ABIs: the server engine must behave exactly like
/// the protocol whichever one it runs on.
void main() {
  late Directory root;
  var next = 0;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('dart_db_conformance');
  });
  tearDownAll(() => root.delete(recursive: true));

  Future<String> freshPath() async => '${root.path}/db-${next++}';

  // The ABI v1 alone, as libraries before offline_first_core 0.7.6 offer.
  final abiV1 = NativeEngine(
    NativeSymbols(
      open: Native.addressOf(Bindings.open),
      execute: Native.addressOf(Bindings.execute),
      freeString: Native.addressOf(Bindings.freeString),
      close: Native.addressOf(Bindings.close),
    ),
  );

  test('the bundled engine runs on the ABI v2', () async {
    final opened = await OfflineFirstCore.engine.open(
      await freshPath(),
      const DbOptions(),
    );
    final connection = opened.when(
      ok: (connection) => connection,
      err: (error) => fail('open: $error'),
    );

    expect((connection as NativeConnection).usesAbiV2, isTrue);
    expect(await connection.close(), isA<Ok<(), DbError>>());
    expect(
      await connection.send(const TablesRequest()),
      isA<Err<Map<String, Object?>, DbError>>(),
      reason: 'a closed connection answers an error',
    );
  });

  for (final (abi, engine) in [
    ('ABI v2', OfflineFirstCore.engine),
    ('ABI v1', abiV1),
  ]) {
    group(abi, () {
      final host = ConformanceHost(engine, freshPath);

      for (final ConformanceCase(:group, :name, :run) in Conformance.cases) {
        test('$group: $name', () => run(host));
      }
    });
  }
}
