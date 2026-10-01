/// A program that only takes the addresses of the bindings, as db_dsl's
/// worker needs them, and prints them. Compiled ahead of time, the bindings
/// must still resolve.
library;

import 'dart:io';

import 'package:dart_db/src/native/offline_first_core.dart';

void main() {
  final symbols = OfflineFirstCore.symbols;

  stdout.writeln(
    [
      symbols.open,
      symbols.execute,
      symbols.freeString,
      symbols.close,
    ].map((pointer) => pointer.address).join(' '),
  );
}
