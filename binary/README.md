# Native Binaries for Dart DB

This directory contains pre-compiled native binaries for the LMDB database backend.

## 📁 Directory Structure

```
binary/
├── linux/
│   └── liboffline_first_core.so          # Linux x86_64 binary
├── macos/
│   ├── liboffline_first_core.dylib       # macOS ARM64 (M1/M2)
│   └── liboffline_first_core_x86_64.dylib # macOS Intel x86_64
└── windows/
    └── (future: liboffline_first_core.dll)
```

## 🎯 Platform Support

### ✅ Linux (Production Ready)
- **File**: `linux/liboffline_first_core.so`
- **Architecture**: x86_64
- **Target**: Linux servers, Docker containers
- **Status**: Fully tested and production ready

### ✅ macOS (Development Ready)
- **ARM64 (M1/M2)**: `macos/liboffline_first_core.dylib`
- **Intel x86_64**: `macos/liboffline_first_core_x86_64.dylib`
- **Target**: Local development on macOS
- **Status**: Ready for development and testing

### 🚧 Windows (Future)
- **File**: `windows/liboffline_first_core.dll`
- **Status**: Not yet available

## 🔧 How Library Loading Works

The `LibraryLoader` automatically detects your platform and loads the appropriate binary:

1. **Platform Detection**: Detects OS (Linux, macOS, Windows)
2. **Architecture Detection**: Detects CPU architecture (x86_64, ARM64)
3. **Binary Search**: Looks for binaries in these locations:
   - Project binary directory (`binary/{platform}/`)
   - Application directory (`./`)
   - System library paths

## 📦 Usage

The library loading is automatic - just use the API:

```dart
import 'package:dart_db/dart_db.dart';

// Library automatically loads the correct binary for your platform
final result = DB.open('my_database');
```

## 🛠️ Development Notes

### Building Binaries

The binaries are built from the `offline_first_core` Rust project:

```bash
# Linux (cross-compile or build on Linux)
cargo build --release --target x86_64-unknown-linux-gnu

# macOS ARM64 (M1/M2)
cargo build --release --target aarch64-apple-darwin

# macOS Intel
cargo build --release --target x86_64-apple-darwin

# Windows (cross-compile or build on Windows)
cargo build --release --target x86_64-pc-windows-msvc
```

### Binary Verification

All binaries should export these functions:
- `create_db`
- `put`
- `get`
- `delete`
- `exists`
- `get_all_keys`
- `get_all`
- `get_stats`
- `clear`
- `close_db`
- `free_string`

## 📊 Binary Information

| Platform | File | Size | Target |
|----------|------|------|---------|
| Linux | liboffline_first_core.so | ~477KB | x86_64 servers |
| macOS ARM | liboffline_first_core.dylib | ~XXX KB | M1/M2 development |
| macOS Intel | liboffline_first_core_x86_64.dylib | ~XXX KB | Intel development |

## 🔒 Security

- All binaries are built from the same Rust source code
- No network access or external dependencies
- Only file system operations for database storage
- Memory-safe Rust implementation with FFI wrapper

---

**Built by**: JhonaCode (Jhonatan Ortiz)  
**Contact**: info@jhonacode.com  
**Source**: [offline_first_core](../../../03_Rust/LibsProjects/offline_first_core/)