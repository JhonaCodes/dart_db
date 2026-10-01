/// Entry points of offline_first_core (Rust + LMDB 1.0).
///
/// They resolve against the code asset `hook/build.dart` bundles for the
/// target platform, so no library is opened by path.
///
/// Why every package that bundles the binary declares its own bindings: the
/// asset id of `@DefaultAsset` names the package whose hook provides the
/// library, and it is fixed at compile time. db_dsl receives their
/// addresses and does the rest.
@DefaultAsset('package:dart_db/src/native/bindings.dart')
library;

import 'dart:ffi';

import 'package:ffi/ffi.dart';

/// The C ABI of offline_first_core. Every returned string belongs to Rust and
/// is released with [freeString], exactly once.
///
/// Why `@pragma('vm:entry-point')` on each function: they are only used
/// through `Native.addressOf` (db_dsl's worker calls the addresses), and an
/// ahead-of-time build (`dart build cli`) can drop how such a function
/// resolves; its address then fails with "No asset with id 'String: null'"
/// (seen on every platform for a program that only takes addresses, and on
/// Windows for the server).
abstract final class Bindings {
  /// `ofc_open(path, options, out)`: opens `<path>.lmdb`; writes the handle to
  /// `out` and returns the wire response.
  @pragma('vm:entry-point')
  @Native<
    Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Pointer<Void>>)
  >(symbol: 'ofc_open')
  external static Pointer<Utf8> open(
    Pointer<Utf8> path,
    Pointer<Utf8> options,
    Pointer<Pointer<Void>> out,
  );

  /// `ofc_execute(handle, request)`: runs one wire-protocol request.
  @pragma('vm:entry-point')
  @Native<Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>)>(
    symbol: 'ofc_execute',
  )
  external static Pointer<Utf8> execute(
    Pointer<Void> handle,
    Pointer<Utf8> request,
  );

  /// `ofc_free_string(string)`: releases a returned string.
  @pragma('vm:entry-point')
  @Native<Void Function(Pointer<Utf8>)>(symbol: 'ofc_free_string')
  external static void freeString(Pointer<Utf8> string);

  /// `close_database(handle)`: releases a handle.
  @pragma('vm:entry-point')
  @Native<Pointer<Utf8> Function(Pointer<Void>)>(symbol: 'close_database')
  external static Pointer<Utf8> close(Pointer<Void> handle);

  /// `ldb_open(path, path_len, options, options_len, out, response)` of the
  /// ABI v2: opens `<path>.lmdb`; writes a `u64` handle and a response
  /// buffer; answers a status.
  @pragma('vm:entry-point')
  @Native<
    Int32 Function(
      Pointer<Uint8>,
      Size,
      Pointer<Uint8>,
      Size,
      Pointer<Uint64>,
      Pointer<Uint64>,
    )
  >(symbol: 'ldb_open')
  external static int ldbOpen(
    Pointer<Uint8> path,
    int pathLength,
    Pointer<Uint8> options,
    int optionsLength,
    Pointer<Uint64> out,
    Pointer<Uint64> response,
  );

  /// `ldb_execute(database, request, request_len, response)` of the ABI v2.
  @pragma('vm:entry-point')
  @Native<Int32 Function(Uint64, Pointer<Uint8>, Size, Pointer<Uint64>)>(
    symbol: 'ldb_execute',
  )
  external static int ldbExecute(
    int database,
    Pointer<Uint8> request,
    int requestLength,
    Pointer<Uint64> response,
  );

  /// `ldb_buffer_view(buffer, data, len)` of the ABI v2.
  @pragma('vm:entry-point')
  @Native<Int32 Function(Uint64, Pointer<Pointer<Uint8>>, Pointer<Size>)>(
    symbol: 'ldb_buffer_view',
  )
  external static int ldbBufferView(
    int buffer,
    Pointer<Pointer<Uint8>> data,
    Pointer<Size> length,
  );

  /// `ldb_buffer_release(buffer)` of the ABI v2.
  @pragma('vm:entry-point')
  @Native<Int32 Function(Uint64)>(symbol: 'ldb_buffer_release')
  external static int ldbBufferRelease(int buffer);

  /// `ldb_close(database)` of the ABI v2.
  @pragma('vm:entry-point')
  @Native<Int32 Function(Uint64)>(symbol: 'ldb_close')
  external static int ldbClose(int database);
}
