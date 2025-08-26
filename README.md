# 🚀 Dart DB

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Dart](https://img.shields.io/badge/Dart-2.17%2B-blue.svg)](https://dart.dev/)
[![Backend](https://img.shields.io/badge/Backend-Linux-green.svg)](https://dart.dev/)

> High-Performance Embedded Database for Dart Backend Applications

**Dart DB** is a blazing-fast, embedded key-value database built specifically for **pure Dart backend applications**. It leverages a pre-compiled Linux binary with LMDB through FFI for maximum performance while maintaining a clean, type-safe API.

## ✨ Features

- **🏃‍♂️ Blazing Fast**: Direct FFI bindings to native LMDB for maximum performance
- **📦 Embedded**: No external database server required - perfect for microservices
- **🛡️ Type Safe**: Full Result<T,E> pattern for error handling - no exceptions
- **🏗️ Instance-based**: Clean API design with multiple database instances
- **🐧 Linux Optimized**: Built specifically for Linux backend deployments
- **🔧 Zero Dependencies**: Pure Dart implementation with minimal footprint
- **⚡ Server-Grade**: Production-ready for high-throughput backend applications

## 🎯 Perfect For

- **API Caches** - Lightning-fast response caching
- **Session Storage** - User session management
- **Configuration Store** - Application settings and config
- **Rate Limiting** - Request throttling data
- **Blacklists/Whitelists** - User and IP management
- **Temporary Data** - Short-lived backend data storage

## 🚀 Quick Start

### Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  dart_db:
    git:
      url: https://github.com/jhonacode/dart_db.git
      ref: main
```

### Basic Usage

```dart
import 'package:dart_db/dart_db.dart';

void main() async {
  // Open database instance
  final result = DB.open('my_cache');
  if (result.isErr) {
    print('Error: ${result.errOrNull}');
    return;
  }
  
  final db = result.okOrNull!;
  
  try {
    // Store data (returns the stored data)
    final storeResult = db.post('user_123', {
      'name': 'John Doe',
      'email': 'john@example.com',
      'role': 'admin'
    });
    
    storeResult.when(
      ok: (storedData) => print('Stored: ${storedData['name']}'),
      err: (error) => print('Error: $error'),
    );
    
    // Retrieve data
    final userData = db.get('user_123');
    userData.when(
      ok: (data) => print('User: ${data['name']}'),
      err: (error) => print('Error: $error'),
    );
    
    // Partial update (patch)
    final updateResult = db.patch('user_123', {'role': 'super_admin'});
    updateResult.when(
      ok: (updatedData) => print('Updated: ${updatedData}'),
      err: (error) => print('Error: $error'),
    );
    
    // Check existence
    final exists = db.exists('user_123');
    print('User exists: ${exists.okOrNull ?? false}');
    
    // List all keys
    final keys = db.keys();
    keys.when(
      ok: (keyList) => print('Keys: $keyList'),
      err: (error) => print('Error: $error'),
    );
    
  } finally {
    db.close();
  }
}
```

## 📖 API Reference

### Opening Database

```dart
// Open database instance
final result = DB.open('database_name');

// With custom path
final result = DB.open('/path/to/database');
```

### Core Operations

```dart
final db = result.okOrNull!;

// Store data (create or update)
await db.put(key, value);

// Create new entry (fails if exists)
await db.post(key, value);

// Retrieve data
final data = await db.get(key);

// Check if key exists
final exists = await db.exists(key);

// Delete entry
await db.delete(key);
```

### Batch Operations

```dart
// Get all keys
final keys = await db.keys();

// Get all data
final allData = await db.all();

// Clear all data
await db.clear();
```

### Database Management

```dart
// Get database statistics
final stats = await db.getStats();

// Close database
await db.close();
```

## 🔧 Advanced Examples

### Session Management

```dart
final sessions = DB.open('user_sessions').okOrNull!;

// Store user session
await sessions.post('session_abc123', {
  'userId': 'user_12345',
  'loginTime': DateTime.now().toIso8601String(),
  'role': 'admin',
  'permissions': ['read', 'write', 'delete'],
});

// Check session
final sessionData = await sessions.get('session_abc123');
sessionData.when(
  ok: (data) => handleValidSession(data),
  err: (_) => handleInvalidSession(),
);
```

### API Cache

```dart
final cache = DB.open('api_cache').okOrNull!;

// Cache API response
await cache.put('api_users_page_1', {
  'data': [...], // API response data
  'timestamp': DateTime.now().toIso8601String(),
  'ttl': DateTime.now().add(Duration(hours: 1)).toIso8601String(),
});

// Retrieve from cache
final cached = await cache.get('api_users_page_1');
```

### Configuration Store

```dart
final config = DB.open('app_config').okOrNull!;

await config.put('server_config', {
  'database_url': 'postgresql://localhost:5432/myapp',
  'jwt_secret': 'your-secret-key',
  'rate_limit': {'requests_per_minute': 100},
});
```

### Blacklist Management

```dart
final blacklist = DB.open('black_list').okOrNull!;

// Add to blacklist
await blacklist.post('user_123', {
  'reason': 'Suspicious activity',
  'blockedAt': DateTime.now().toIso8601String(),
  'severity': 'high',
});

// Check if blocked
final isBlocked = await blacklist.exists('user_123');
```

## ⚡ Performance

Dart DB is optimized for high-throughput backend applications:

- **Direct FFI**: No overhead from Dart-native bridge
- **LMDB Backend**: Memory-mapped storage for maximum speed
- **Linux Optimized**: Built specifically for server environments
- **Minimal Allocations**: Efficient memory usage patterns

## 📦 Native Library Included

✅ **Ready to use!** The dart_db package includes the pre-compiled Linux binary:

- **Location**: `lib/liboffline_first_core.so` 
- **Target**: Linux x86_64 servers and containers
- **Auto-discovery**: Library loader automatically finds the binary
- **No manual setup**: Just add the dependency and start coding!

## 🗂️ Error Handling

Dart DB uses a comprehensive Result<T,E> pattern:

```dart
final result = await db.get('key');

// Pattern matching
result.when(
  ok: (data) {
    // Handle success
    print('Data: $data');
  },
  err: (error) {
    // Handle specific errors
    switch (error.type) {
      case DbErrorType.notFound:
        print('Key not found');
        break;
      case DbErrorType.database:
        print('Database error: ${error.message}');
        break;
      default:
        print('Unexpected error: ${error}');
    }
  },
);

// Or check directly
if (result.isOk) {
  final data = result.okOrNull!;
  // Use data
}
```

## 📋 System Requirements

- **OS**: Linux (64-bit)
- **Dart**: 2.17+
- **Runtime**: Pure Dart backend applications only
- **Dependencies**: Native LMDB library - **INCLUDED!** ✅

## 🚀 Deployment

### Development

No setup required! The library includes the binary:

```bash
# Your project structure
my_backend/
├── bin/
│   └── server.dart
├── pubspec.yaml
└── .packages  # dart_db includes lib/liboffline_first_core.so

# Just run your app - library auto-loads!
dart run bin/server.dart
```

### Production

#### Docker (Recommended)

```dockerfile
FROM dart:stable

# Copy your application
COPY . /app
WORKDIR /app

# Install dependencies (includes native binary)
RUN dart pub get
RUN dart compile exe bin/server.dart -o server

# Run your backend
CMD ["./server"]
```

#### Linux Server

```bash
# The binary is included with the package
dart pub get
dart compile exe bin/server.dart -o server
./server

# Or for development
dart run bin/server.dart
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👤 Author

**JhonaCode (Jhonatan Ortiz)**
- Email: info@jhonacode.com
- Specializing in high-performance backend solutions

---

Built with ❤️ for the Dart backend community