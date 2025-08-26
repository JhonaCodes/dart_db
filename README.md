# 🚀 Dart DB

[![pub package](https://img.shields.io/pub/v/dart_db.svg)](https://pub.dev/packages/dart_db)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Dart](https://img.shields.io/badge/Dart-3.0%2B-blue.svg)](https://dart.dev/)
[![Server](https://img.shields.io/badge/Platform-Server-green.svg)](https://dart.dev/)

> High-Performance Embedded Database for Dart Server Applications

**Dart DB** is a blazing-fast, embedded key-value database built specifically for **Dart server applications**. It leverages LMDB through Rust FFI for maximum performance while maintaining a clean, simplified API perfect for APIs, microservices, and backend systems.

### 🆕 Version 0.2.0 - Simplified & Server-Focused

- ✅ **Simplified JSON handling** - Direct `jsonEncode`/`jsonDecode` 
- ✅ **Simple path resolution** - No complex hardcoded paths
- ✅ **Published on pub.dev** - Easy installation with `dart pub add dart_db`
- ✅ **Server-first design** - Optimized for backend applications only
- ✅ **Rust FFI backend** - Maximum performance with LMDB

## ✨ Features

- **🏃‍♂️ Blazing Fast**: Rust FFI bindings to LMDB for maximum performance
- **📦 Embedded**: No external database server required - perfect for microservices
- **🛡️ Type Safe**: Full Result<T,E> pattern for error handling - no exceptions
- **🏗️ Instance-based**: Clean API design with multiple database instances
- **🔧 Simplified**: Direct jsonEncode/jsonDecode with simple path resolution
- **🖥️ Server-First**: Built specifically for server applications, not mobile
- **⚡ Production Ready**: High-throughput backend applications and APIs

## 🎯 Perfect For

- **🚀 REST APIs** - Lightning-fast data caching and session storage
- **🔐 Authentication** - User session and JWT token management
- **⚙️ Configuration** - Application settings and environment config
- **🚦 Rate Limiting** - Request throttling and IP tracking
- **📝 Logging** - Request logs and audit trails
- **🛡️ Security** - Blacklists, whitelists, and security rules
- **🔄 Microservices** - Inter-service data sharing and caching

## 🚀 Quick Start

### Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  dart_db: ^0.2.0
```

Or install via command line:

```bash
dart pub add dart_db
```

### Basic Usage

```dart
import 'package:dart_db/dart_db.dart';

void main() async {
  // Open database instance
  final result = DB.open('user_sessions');
  if (result.isErr) {
    print('Error: ${result.errOrNull}');
    return;
  }
  
  final db = result.okOrNull!;
  
  // Store user session data
  final storeResult = db.post('session_123', {
    'userId': 'user_456', 
    'email': 'john@example.com',
    'role': 'admin',
    'loginAt': DateTime.now().toIso8601String(),
  });
  
  storeResult.when(
    ok: (storedData) => print('Session stored: ${storedData['userId']}'),
    err: (error) => print('Error: $error'),
  );
  
  // Retrieve session data
  final sessionData = db.get('session_123');
  sessionData.when(
    ok: (data) => print('Found user: ${data['email']}'),
    err: (error) => print('Session not found: $error'),
  );
  
  // Update session
  final updateResult = db.put('session_123', {
    'userId': 'user_456',
    'email': 'john@example.com', 
    'role': 'super_admin',  // Updated role
    'lastActivity': DateTime.now().toIso8601String(),
  });
  
  updateResult.when(
    ok: (updatedData) => print('Updated role: ${updatedData['role']}'),
    err: (error) => print('Update failed: $error'),
  );
  
  // Check if session exists
  final existsResult = db.exists('session_123');
  existsResult.when(
    ok: (exists) => print('Session active: $exists'),
    err: (error) => print('Error: $error'),
  );
  
  // Get all active sessions
  final allSessions = db.all();
  allSessions.when(
    ok: (sessions) => print('Active sessions: ${sessions.length}'),
    err: (error) => print('Error: $error'),
  );
  
  // Clean up
  db.close();
}
```

## 📖 API Reference

### Opening Database

```dart
// Open database with name (stored in system data directory)
final result = DB.open('my_api_cache');

// With custom filename
final result = DB.open('sessions.lmdb');

// With absolute path
final result = DB.open('/path/to/database.lmdb');
```

### Core Operations

```dart
final db = result.okOrNull!;

// CREATE - Store new data (returns stored data)
final createResult = db.post('user_123', {'name': 'John', 'role': 'admin'});

// READ - Retrieve data
final readResult = db.get('user_123');

// UPDATE - Modify existing data (same as post)  
final updateResult = db.put('user_123', {'name': 'John', 'role': 'super_admin'});

// DELETE - Remove entry
final deleteResult = db.delete('user_123');

// EXISTS - Check if key exists
final existsResult = db.exists('user_123');
```

### Batch Operations

```dart
// Get all stored keys
final keysResult = db.keys();  // Returns List<String>

// Get all key-value pairs
final allResult = db.all();    // Returns Map<String, Map<String, dynamic>>

// Clear entire database
final clearResult = db.clear();
```

### Database Management

```dart
// Close database (always call when done!)
db.close();

// Check if database is closed
final isClosed = db.isClosed;  // Returns bool

// Get database name
final name = db.name;          // Returns String
```

## 🔧 Advanced Examples

### REST API Session Management

```dart
final sessions = DB.open('user_sessions').okOrNull!;

// Store user session after login
final loginResult = sessions.post('session_abc123', {
  'userId': 'user_12345',
  'email': 'user@example.com', 
  'role': 'admin',
  'permissions': ['read', 'write', 'delete'],
  'loginTime': DateTime.now().toIso8601String(),
  'lastActivity': DateTime.now().toIso8601String(),
});

// Middleware: Check session validity
final sessionResult = sessions.get('session_abc123');
sessionResult.when(
  ok: (sessionData) {
    // Update last activity
    sessionData['lastActivity'] = DateTime.now().toIso8601String();
    sessions.put('session_abc123', sessionData);
    return handleValidSession(sessionData);
  },
  err: (_) => return handleUnauthorized(),
);

// Logout: Remove session
sessions.delete('session_abc123');
```

### High-Performance API Cache

```dart
final cache = DB.open('api_cache').okOrNull!;

// Cache database query results
final userListResult = cache.post('users_page_1', {
  'data': [...], // Expensive database query result
  'timestamp': DateTime.now().toIso8601String(),
  'ttl': DateTime.now().add(Duration(hours: 1)).toIso8601String(),
  'query_hash': 'users_active_page_1',
});

// Check cache before hitting database
final cacheResult = cache.get('users_page_1');
cacheResult.when(
  ok: (cachedData) {
    final ttl = DateTime.parse(cachedData['ttl']);
    if (DateTime.now().isBefore(ttl)) {
      return Response.json(cachedData['data']); // Return cached
    } else {
      cache.delete('users_page_1'); // Expired, remove
      return await fetchFromDatabase(); // Fetch fresh
    }
  },
  err: (_) => await fetchFromDatabase(), // Cache miss
);
```

### Environment Configuration

```dart
final config = DB.open('server_config').okOrNull!;

// Store server configuration
config.post('database', {
  'host': 'localhost',
  'port': 5432,
  'database': 'myapp_prod',
  'pool_size': 20,
});

config.post('jwt', {
  'secret': Platform.environment['JWT_SECRET'] ?? 'dev-secret',
  'expires_in': '24h',
  'algorithm': 'HS256',
});

// Read configuration in your server startup
final dbConfig = config.get('database').okOrNull!;
final jwtConfig = config.get('jwt').okOrNull!;
```

### Rate Limiting & Security

```dart
final rateLimiter = DB.open('rate_limits').okOrNull!;
final blacklist = DB.open('security_blacklist').okOrNull!;

// Rate limiting per IP
final clientIp = '192.168.1.100';
final requestCount = rateLimiter.get(clientIp);

requestCount.when(
  ok: (data) {
    final count = data['requests'] as int;
    if (count > 100) { // 100 requests per hour
      return Response.json({'error': 'Rate limit exceeded'}, 429);
    }
    // Increment counter
    rateLimiter.put(clientIp, {'requests': count + 1, 'reset_at': data['reset_at']});
  },
  err: (_) {
    // First request from this IP
    rateLimiter.post(clientIp, {
      'requests': 1, 
      'reset_at': DateTime.now().add(Duration(hours: 1)).toIso8601String()
    });
  },
);

// Security blacklist check
final isBlacklisted = blacklist.exists(clientIp);
isBlacklisted.when(
  ok: (exists) {
    if (exists) return Response.json({'error': 'Access denied'}, 403);
  },
  err: (_) => {}, // Not blacklisted
);
```

## ⚡ Performance

Dart DB is optimized for high-throughput server applications:

- **🦀 Rust FFI**: Direct bindings to LMDB via optimized Rust backend
- **💾 LMDB**: Memory-mapped B+ tree storage for maximum speed
- **🖥️ Server Optimized**: Built specifically for Linux/macOS server environments
- **⚡ Simplified**: Direct JSON encoding/decoding with minimal overhead
- **🔄 Instance-Based**: Multiple databases in single process

## 📦 Native Binaries Included

✅ **Ready to use!** The dart_db package includes pre-compiled binaries for:

- **Linux**: `binary/linux/liboffline_first_core.so` (x86_64)
- **macOS**: `binary/macos/liboffline_first_core.dylib` (ARM64 + Intel)
- **Windows**: `binary/windows/` (for development/testing)
- **Auto-discovery**: Library loader automatically finds the correct binary
- **Zero setup**: Just `dart pub add dart_db` and start coding!

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

- **OS**: Linux (primary), macOS (supported), Windows (development only)
- **Dart**: 3.0+
- **Architecture**: x86_64 (Linux), ARM64 + Intel (macOS)
- **Use Case**: **Server applications only** - APIs, microservices, backend systems
- **Dependencies**: Native LMDB library via Rust - **INCLUDED!** ✅
- **NOT for**: Mobile apps, Flutter apps, client-side applications

## 🚀 Deployment

### Development

Zero setup required! Just add the dependency and start coding:

```bash
# Create your server project
dart create -t server-shelf my_api
cd my_api

# Add dart_db
dart pub add dart_db

# Your project structure
my_api/
├── bin/
│   └── server.dart        # Your API server
├── pubspec.yaml           # dart_db: ^0.2.0
└── lib/
    └── api/
        ├── sessions.dart   # Session management
        ├── cache.dart      # API caching
        └── config.dart     # Server config

# Run your server - binaries auto-load!
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