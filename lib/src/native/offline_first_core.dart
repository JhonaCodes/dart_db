/// The offline_first_core library bundled by dart_db, as seen by db_dsl.
library;

import 'dart:ffi';

import 'package:db_dsl/native.dart';

import 'bindings.dart';

/// The functions of the offline_first_core binary that `hook/build.dart`
/// bundles, handed to db_dsl.
///
/// Why addresses: db_dsl runs every call on its worker isolate but never
/// loads a binary; the `@Native` bindings of this package resolve the
/// bundled one, and db_dsl calls them through their addresses.
abstract final class OfflineFirstCore {
  /// The query API functions.
  static final NativeSymbols symbols = NativeSymbols(
    open: Native.addressOf(Bindings.open),
    execute: Native.addressOf(Bindings.execute),
    freeString: Native.addressOf(Bindings.freeString),
    close: Native.addressOf(Bindings.close),
    abiV2: AbiV2Symbols(
      open: Native.addressOf(Bindings.ldbOpen),
      execute: Native.addressOf(Bindings.ldbExecute),
      bufferView: Native.addressOf(Bindings.ldbBufferView),
      bufferRelease: Native.addressOf(Bindings.ldbBufferRelease),
      close: Native.addressOf(Bindings.ldbClose),
    ),
  );

  /// The query engine of db_dsl on this library.
  static final NativeEngine engine = NativeEngine(symbols);
}
