// Temporary diagnosis of the Windows bundle: a direct @Native call against
// Native.addressOf. Removed once the cause is known.
import 'dart:ffi';
import 'dart:io';

import 'package:dart_db/src/native/bindings.dart';
import 'package:ffi/ffi.dart';

void main(List<String> args) {
  final path = '${args.first}/direct'.toNativeUtf8();
  final options = '{}'.toNativeUtf8();
  final out = calloc<Pointer<Void>>();

  try {
    final reply = Bindings.open(path, options, out);
    stdout.writeln('direct call: ${reply.toDartString()}');
  } on Object catch (error) {
    stdout.writeln('direct call failed: $error');
  }

  try {
    final address =
        Native.addressOf<
          NativeFunction<
            Pointer<Utf8> Function(
              Pointer<Utf8>,
              Pointer<Utf8>,
              Pointer<Pointer<Void>>,
            )
          >
        >(Bindings.open);
    stdout.writeln('addressOf: ${address.address}');
  } on Object catch (error) {
    stdout.writeln('addressOf failed: $error');
  }
}
