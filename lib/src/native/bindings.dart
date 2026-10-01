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
abstract final class Bindings {
  /// `ofc_open(path, options, out)`: opens `<path>.lmdb`; writes the handle to
  /// `out` and returns the wire response.
  @Native<
    Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Pointer<Void>>)
  >(symbol: 'ofc_open')
  external static Pointer<Utf8> open(
    Pointer<Utf8> path,
    Pointer<Utf8> options,
    Pointer<Pointer<Void>> out,
  );

  /// `ofc_execute(handle, request)`: runs one wire-protocol request.
  @Native<Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>)>(
    symbol: 'ofc_execute',
  )
  external static Pointer<Utf8> execute(
    Pointer<Void> handle,
    Pointer<Utf8> request,
  );

  /// `ofc_free_string(string)`: releases a returned string.
  @Native<Void Function(Pointer<Utf8>)>(symbol: 'ofc_free_string')
  external static void freeString(Pointer<Utf8> string);

  /// `close_database(handle)`: releases a handle.
  @Native<Pointer<Utf8> Function(Pointer<Void>)>(symbol: 'close_database')
  external static Pointer<Utf8> close(Pointer<Void> handle);
}
