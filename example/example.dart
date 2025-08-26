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

import 'package:dart_db/dart_db.dart';

/// Simple CRUD example using dart_db
///
/// Demonstrates basic Create, Read, Update, Delete operations
/// with the simplified dart_db API.
void main() async {
  print('🚀 dart_db Simple CRUD Example');
  print('================================\n');

  // 1. Open database
  print('📂 Opening database...');
  final dbResult = DB.open('users_example');

  if (dbResult.isErr) {
    print('❌ Failed to open database: ${dbResult.errOrNull}');
    return;
  }

  final db = dbResult.okOrNull!;
  print('✅ Database opened successfully\n');

  // 2. CREATE - Store user data
  print('➕ CREATE: Storing users...');

  final users = [
    {
      'name': 'Juan Pérez',
      'email': 'juan@example.com',
      'age': 30,
      'department': 'Engineering',
      'active': true,
    },
    {
      'name': 'María García',
      'email': 'maria@example.com',
      'age': 28,
      'department': 'Design',
      'active': true,
    },
    {
      'name': 'Carlos López',
      'email': 'carlos@example.com',
      'age': 35,
      'department': 'Marketing',
      'active': false,
    }
  ];

  for (int i = 0; i < users.length; i++) {
    final userId = 'user_${i + 1}';
    final storeResult = db.post(userId, users[i]);

    storeResult.when(
      ok: (data) => print('✅ Stored user: $userId'),
      err: (error) => print('❌ Failed to store $userId: $error'),
    );
  }

  print('');

  // 3. READ - Retrieve individual users
  print('👁️  READ: Retrieving users...');

  for (int i = 1; i <= 3; i++) {
    final userId = 'user_$i';
    final getUserResult = db.get(userId);

    getUserResult.when(
      ok: (userData) {
        print('✅ User $userId: ${userData['name']} - ${userData['email']}');
      },
      err: (error) => print('❌ User $userId not found: $error'),
    );
  }

  print('');

  // 4. UPDATE - Modify user data
  print('📝 UPDATE: Modifying user_2...');

  final updateResult = db.put('user_2', {
    'name': 'María García Rodríguez', // Updated name
    'email': 'maria.garcia@example.com', // Updated email
    'age': 29, // Updated age
    'department': 'Senior Design', // Updated department
    'active': true,
    'last_updated': DateTime.now().toIso8601String(),
  });

  updateResult.when(
    ok: (data) {
      print('✅ User updated successfully');
      print('   New data: ${data['name']} - ${data['email']}');
    },
    err: (error) => print('❌ Failed to update user: $error'),
  );

  print('');

  // 5. READ - Verify update
  print('🔍 Verifying update...');
  final verifyResult = db.get('user_2');
  verifyResult.when(
    ok: (data) => print('✅ Updated user_2: ${data['name']} - ${data['email']}'),
    err: (error) => print('❌ Failed to verify update: $error'),
  );

  print('');

  // 6. LIST ALL - Show all stored data
  print('📋 LIST ALL: Showing all users...');
  final allDataResult = db.all();

  allDataResult.when(
    ok: (allData) {
      print('📊 Total users: ${allData.length}');
      allData.forEach((key, userData) {
        final status = userData['active'] == true ? '🟢' : '🔴';
        print(
            '   $status $key: ${userData['name']} (${userData['department']})');
      });
    },
    err: (error) => print('❌ Failed to retrieve all data: $error'),
  );

  print('');

  // 7. SEARCH - Find specific users
  print('🔎 SEARCH: Finding active users...');
  allDataResult.when(
    ok: (allData) {
      final activeUsers = <String, Map<String, dynamic>>{};

      allData.forEach((key, userData) {
        if (userData['active'] == true) {
          activeUsers[key] = userData;
        }
      });

      print('👥 Active users (${activeUsers.length}):');
      activeUsers.forEach((key, userData) {
        print('   🟢 $key: ${userData['name']} - ${userData['department']}');
      });
    },
    err: (error) => print('❌ Failed to search users: $error'),
  );

  print('');

  // 8. DELETE - Remove a user
  print('🗑️  DELETE: Removing user_3...');
  final deleteResult = db.delete('user_3');

  deleteResult.when(
    ok: (_) => print('✅ User user_3 deleted successfully'),
    err: (error) => print('❌ Failed to delete user_3: $error'),
  );

  print('');

  // 9. VERIFY DELETE - Confirm deletion
  print('🔍 Verifying deletion...');
  final verifyDeleteResult = db.get('user_3');
  verifyDeleteResult.when(
    ok: (data) => print('⚠️  user_3 still exists: ${data['name']}'),
    err: (error) => print('✅ Confirmed: user_3 has been deleted'),
  );

  print('');

  // 10. FINAL COUNT - Show remaining data
  print('📊 FINAL COUNT: Remaining users...');
  final finalCountResult = db.keys();
  finalCountResult.when(
    ok: (keys) =>
        print('📈 Total remaining users: ${keys.length} (${keys.join(', ')})'),
    err: (error) => print('❌ Failed to count remaining users: $error'),
  );

  print('');

  // 11. BATCH OPERATIONS - Add multiple users at once
  print('📦 BATCH: Adding more users...');

  final batchUsers = [
    (
      'user_4',
      {
        'name': 'Ana Martín',
        'email': 'ana@example.com',
        'age': 26,
        'department': 'HR',
        'active': true,
      }
    ),
    (
      'user_5',
      {
        'name': 'Diego Fernández',
        'email': 'diego@example.com',
        'age': 32,
        'department': 'Sales',
        'active': true,
      }
    ),
  ];

  for (final (userId, userData) in batchUsers) {
    final result = db.post(userId, userData);
    result.when(
      ok: (_) => print('✅ Batch added: $userId'),
      err: (error) => print('❌ Failed to add $userId: $error'),
    );
  }

  print('');

  // 12. EXISTS CHECK - Test if keys exist
  print('🔍 EXISTS CHECK: Checking key existence...');

  for (final key in ['user_1', 'user_2', 'user_nonexistent']) {
    final existsResult = db.exists(key);
    existsResult.when(
      ok: (exists) => print(
          '   ${exists ? '✅' : '❌'} $key: ${exists ? 'exists' : 'not found'}'),
      err: (error) => print('   ❌ Error checking $key: $error'),
    );
  }

  print('');

  // 14. Close database
  print('🔒 Closing database...');
  db.close();
  print('✅ Database closed successfully');

  print('\n🎉 CRUD Example completed successfully!');
  print('   All operations demonstrate the simplified dart_db API');
  print('   with direct jsonEncode/jsonDecode and simple path resolution.');
}
