// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║                             DART DB EXAMPLES                                ║
// ║              High-Performance Backend Database Usage Examples                ║
// ║══════════════════════════════════════════════════════════════════════════════║
// ║                                                                              ║
// ║  Author: JhonaCode (Jhonatan Ortiz)                                         ║
// ║  Contact: info@jhonacode.com                                                 ║
// ║  Purpose: Demonstrate dart_db usage patterns for backend applications       ║
// ║                                                                              ║
// ║  Features Demonstrated:                                                      ║
// ║    • Instance-based API usage                                                ║
// ║    • Session management                                                      ║
// ║    • Cache operations                                                        ║
// ║    • Configuration storage                                                   ║
// ║    • Error handling patterns                                                 ║
// ║                                                                              ║
// ╚══════════════════════════════════════════════════════════════════════════════╝

import 'dart:convert';
import 'dart:io';
import 'package:dart_db/dart_db.dart';

void main() async {
  print('🚀 Dart DB Backend Examples\n');
  
  // Example 1: Session Management
  await sessionManagementExample();
  
  print('\n${'=' * 50}\n');
  
  // Example 2: Cache Operations
  await cacheExample();
  
  print('\n' + '=' * 50 + '\n');
  
  // Example 3: Configuration Store
  await configurationExample();
  
  print('\n' + '=' * 50 + '\n');
  
  // Example 4: User Blacklist
  await blacklistExample();
  
  print('\n' + '=' * 50 + '\n');
  
  // Example 5: Error Handling
  await errorHandlingExample();
}

/// Example 1: Session Management for Web Backend
Future<void> sessionManagementExample() async {
  print('📱 Session Management Example');
  print('Managing user sessions in a web backend');
  
  final result = DB.open('user_sessions');
  if (result.isErr) {
    print('❌ Failed to open sessions database: ${result.errOrNull}');
    return;
  }
  
  final sessions = result.okOrNull!;
  
  try {
    // Store user session
    final sessionData = {
      'userId': 'user_12345',
      'username': 'jhonacode',
      'loginTime': DateTime.now().toIso8601String(),
      'ipAddress': '192.168.1.100',
      'userAgent': 'Mozilla/5.0 (Linux; Backend)',
      'role': 'admin',
      'permissions': ['read', 'write', 'delete'],
    };
    
    final putResult = await sessions.post('session_abc123', sessionData);
    putResult.when(
      ok: (_) => print('✅ Session stored successfully'),
      err: (error) => print('❌ Failed to store session: $error'),
    );
    
    // Retrieve session
    final getResult = await sessions.get('session_abc123');
    getResult.when(
      ok: (data) {
        print('📖 Retrieved session: ${data?['username']} (${data?['role']})');
        print('   Login time: ${data?['loginTime']}');
      },
      err: (error) => print('❌ Session not found: $error'),
    );
    
    // Check if session exists
    final existsResult = await sessions.exists('session_abc123');
    existsResult.when(
      ok: (exists) => print('🔍 Session exists: $exists'),
      err: (error) => print('❌ Error checking session: $error'),
    );
    
    // List all active sessions
    final keysResult = await sessions.keys();
    keysResult.when(
      ok: (keys) => print('📋 Active sessions: ${keys.length}'),
      err: (error) => print('❌ Error listing sessions: $error'),
    );
    
  } finally {
    await sessions.close();
  }
}

/// Example 2: High-Performance Cache
Future<void> cacheExample() async {
  print('⚡ Cache Operations Example');
  print('Fast data caching for API responses');
  
  final result = DB.open('api_cache');
  if (result.isErr) {
    print('❌ Failed to open cache database: ${result.errOrNull}');
    return;
  }
  
  final cache = result.okOrNull!;
  
  try {
    // Cache API response
    final apiResponse = {
      'endpoint': '/api/users',
      'timestamp': DateTime.now().toIso8601String(),
      'data': [
        {'id': 1, 'name': 'Jhonatan', 'email': 'info@jhonacode.com'},
        {'id': 2, 'name': 'Maria', 'email': 'maria@example.com'},
      ],
      'ttl': DateTime.now().add(Duration(hours: 1)).toIso8601String(),
    };
    
    await cache.put('api_users_page_1', apiResponse);
    print('✅ API response cached');
    
    // Retrieve from cache
    final cachedResult = await cache.get('api_users_page_1');
    cachedResult.when(
      ok: (data) {
        if (data != null) {
          final users = data['data'] as List;
          print('📖 Cache hit: ${users.length} users found');
          print('   Cached at: ${data['timestamp']}');
        }
      },
      err: (error) => print('❌ Cache miss: $error'),
    );
    
    // Cache statistics
    final statsResult = await cache.getStats();
    statsResult.when(
      ok: (stats) => print('📊 Cache stats: $stats'),
      err: (error) => print('❌ Error getting stats: $error'),
    );
    
  } finally {
    await cache.close();
  }
}

/// Example 3: Configuration Management
Future<void> configurationExample() async {
  print('⚙️  Configuration Store Example');
  print('Storing application configuration');
  
  final result = DB.open('app_config');
  if (result.isErr) {
    print('❌ Failed to open config database: ${result.errOrNull}');
    return;
  }
  
  final config = result.okOrNull!;
  
  try {
    // Store configuration
    final appConfig = {
      'app_name': 'Backend API Server',
      'version': '1.0.0',
      'database_url': 'postgresql://localhost:5432/myapp',
      'redis_url': 'redis://localhost:6379',
      'jwt_secret': 'super-secret-key',
      'rate_limit': {
        'requests_per_minute': 100,
        'burst_size': 20,
      },
      'features': {
        'logging': true,
        'metrics': true,
        'auth_required': true,
      },
    };
    
    await config.put('server_config', appConfig);
    print('✅ Configuration stored');
    
    // Retrieve specific config
    final configResult = await config.get('server_config');
    configResult.when(
      ok: (data) {
        if (data != null) {
          print('📖 App: ${data['app_name']} v${data['version']}');
          final features = data['features'] as Map;
          print('   Features: ${features.keys.join(', ')}');
        }
      },
      err: (error) => print('❌ Config not found: $error'),
    );
    
  } finally {
    await config.close();
  }
}

/// Example 4: User Blacklist (as requested in original conversation)
Future<void> blacklistExample() async {
  print('🚫 Blacklist Management Example');
  print('Managing blocked users and IPs');
  
  final result = DB.open('black_list');
  if (result.isErr) {
    print('❌ Failed to open blacklist database: ${result.errOrNull}');
    return;
  }
  
  final blacklist = result.okOrNull!;
  
  try {
    // Add blocked user (as shown in original example)
    final blockedUser = {
      'userId': 'black_3r3f43',
      'reason': 'Suspicious activity detected',
      'blockedAt': DateTime.now().toIso8601String(),
      'blockedBy': 'security_system',
      'ipAddress': '192.168.1.200',
      'severity': 'high',
    };
    
    await blacklist.post('black_3r3f43', blockedUser);
    print('✅ User added to blacklist');
    
    // Check if user is blacklisted
    final checkResult = await blacklist.exists('black_3r3f43');
    checkResult.when(
      ok: (isBlocked) => print('🔍 User blocked: $isBlocked'),
      err: (error) => print('❌ Error checking blacklist: $error'),
    );
    
    // Get all blocked users
    final allResult = await blacklist.all();
    allResult.when(
      ok: (data) {
        final blocked = data.length;
        print('📋 Total blocked users: $blocked');
        
        data.forEach((key, userData) {
          print('   - $key: ${userData['reason']}');
        });
      },
      err: (error) => print('❌ Error listing blocked users: $error'),
    );
    
    // Remove from blacklist
    final deleteResult = await blacklist.delete('black_3r3f43');
    deleteResult.when(
      ok: (_) => print('✅ User removed from blacklist'),
      err: (error) => print('❌ Error removing user: $error'),
    );
    
  } finally {
    await blacklist.close();
  }
}

/// Example 5: Error Handling Patterns
Future<void> errorHandlingExample() async {
  print('🔧 Error Handling Example');
  print('Demonstrating robust error handling');
  
  // Try to open non-existent database path
  final result = DB.open('/invalid/path/database');
  
  result.when(
    ok: (db) async {
      print('✅ Database opened successfully');
      await db.close();
    },
    err: (error) {
      print('❌ Expected error occurred:');
      print('   Type: ${error.type.name}');
      print('   Message: ${error.message}');
      if (error.context != null) {
        print('   Context: ${error.context}');
      }
    },
  );
  
  // Example of handling different error types
  final validResult = DB.open('error_test');
  if (validResult.isOk) {
    final db = validResult.okOrNull!;
    
    try {
      // Try invalid operations
      final invalidResult = await db.get('nonexistent_key');
      invalidResult.when(
        ok: (data) => print('✅ Data found: $data'),
        err: (error) {
          switch (error.type) {
            case DbErrorType.notFound:
              print('ℹ️  Key not found (this is expected)');
              break;
            case DbErrorType.database:
              print('❌ Database error: ${error.message}');
              break;
            default:
              print('❌ Unexpected error: ${error.message}');
          }
        },
      );
      
    } finally {
      await db.close();
    }
  }
}
