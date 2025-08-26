// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║                              DB ERROR                                        ║
// ║                    Comprehensive Error Types for Database                    ║
// ║══════════════════════════════════════════════════════════════════════════════║
// ║                                                                              ║
// ║  Author: JhonaCode (Jhonatan Ortiz)                                         ║
// ║  Contact: info@jhonacode.com                                                 ║
// ║  Module: db_error.dart                                                       ║
// ║  Purpose: Structured error types for database operations                    ║
// ║                                                                              ║
// ║  Description:                                                                ║
// ║    Defines comprehensive error types for all database operations.          ║
// ║    Provides structured error information with context for debugging.       ║
// ║                                                                              ║
// ║  Features:                                                                   ║
// ║    • Structured error types                                                  ║
// ║    • Contextual error messages                                               ║
// ║    • Debug-friendly formatting                                               ║
// ║    • Backend-optimized error handling                                       ║
// ║                                                                              ║
// ╚══════════════════════════════════════════════════════════════════════════════╝

/// Enumeration of all possible error types
enum DbErrorType {
  /// Database could not be initialized or opened
  initialization,
  
  /// Record with the specified key was not found
  notFound,
  
  /// Input validation failed (invalid key, data, etc.)
  validation,
  
  /// Low-level database operation failed
  database,
  
  /// JSON serialization/deserialization failed
  serialization,
  
  /// FFI operation failed (library loading, function calls)
  ffi,
  
  /// Platform-specific operation failed
  platform,
  
  /// Unknown or unexpected error occurred
  unknown,
}

/// Comprehensive error class for database operations
/// 
/// Provides detailed information about what went wrong and where.
/// Optimized for backend debugging and logging.
/// 
/// Example:
/// ```dart
/// if (result.isErr) {
///   final error = result.errOrNull!;
///   print('Error: ${error.message}');
///   if (error.context != null) {
///     print('Context: ${error.context}');
///   }
/// }
/// ```
class DbError {
  /// The type of error that occurred
  final DbErrorType type;
  
  /// Human-readable error message
  final String message;
  
  /// Optional context information (key, operation, etc.)
  final String? context;
  
  /// Optional underlying cause (original exception, etc.)
  final dynamic cause;
  
  /// Optional stack trace for debugging
  final StackTrace? stackTrace;
  
  const DbError({
    required this.type,
    required this.message,
    this.context,
    this.cause,
    this.stackTrace,
  });
  
  /// Creates an initialization error
  factory DbError.initialization(
    String message, {
    String? context,
    dynamic cause,
    StackTrace? stackTrace,
  }) {
    return DbError(
      type: DbErrorType.initialization,
      message: message,
      context: context,
      cause: cause,
      stackTrace: stackTrace,
    );
  }
  
  /// Creates a not found error
  factory DbError.notFound(
    String message, {
    String? context,
    dynamic cause,
    StackTrace? stackTrace,
  }) {
    return DbError(
      type: DbErrorType.notFound,
      message: message,
      context: context,
      cause: cause,
      stackTrace: stackTrace,
    );
  }
  
  /// Creates a validation error
  factory DbError.validation(
    String message, {
    String? context,
    dynamic cause,
    StackTrace? stackTrace,
  }) {
    return DbError(
      type: DbErrorType.validation,
      message: message,
      context: context,
      cause: cause,
      stackTrace: stackTrace,
    );
  }
  
  /// Creates a database error
  factory DbError.database(
    String message, {
    String? context,
    dynamic cause,
    StackTrace? stackTrace,
  }) {
    return DbError(
      type: DbErrorType.database,
      message: message,
      context: context,
      cause: cause,
      stackTrace: stackTrace,
    );
  }
  
  /// Creates a serialization error
  factory DbError.serialization(
    String message, {
    String? context,
    dynamic cause,
    StackTrace? stackTrace,
  }) {
    return DbError(
      type: DbErrorType.serialization,
      message: message,
      context: context,
      cause: cause,
      stackTrace: stackTrace,
    );
  }
  
  /// Creates an FFI error
  factory DbError.ffi(
    String message, {
    String? context,
    dynamic cause,
    StackTrace? stackTrace,
  }) {
    return DbError(
      type: DbErrorType.ffi,
      message: message,
      context: context,
      cause: cause,
      stackTrace: stackTrace,
    );
  }
  
  /// Creates a platform error
  factory DbError.platform(
    String message, {
    String? context,
    dynamic cause,
    StackTrace? stackTrace,
  }) {
    return DbError(
      type: DbErrorType.platform,
      message: message,
      context: context,
      cause: cause,
      stackTrace: stackTrace,
    );
  }
  
  /// Creates an unknown error
  factory DbError.unknown(
    String message, {
    String? context,
    dynamic cause,
    StackTrace? stackTrace,
  }) {
    return DbError(
      type: DbErrorType.unknown,
      message: message,
      context: context,
      cause: cause,
      stackTrace: stackTrace,
    );
  }
  
  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('DbError(${type.name}: $message');
    
    if (context != null) {
      buffer.write(', context: $context');
    }
    
    if (cause != null) {
      buffer.write(', cause: $cause');
    }
    
    buffer.write(')');
    return buffer.toString();
  }
  
  /// Returns a detailed string representation for debugging
  String toDetailedString() {
    final buffer = StringBuffer();
    buffer.writeln('DbError Details:');
    buffer.writeln('  Type: ${type.name}');
    buffer.writeln('  Message: $message');
    
    if (context != null) {
      buffer.writeln('  Context: $context');
    }
    
    if (cause != null) {
      buffer.writeln('  Cause: $cause');
    }
    
    if (stackTrace != null) {
      buffer.writeln('  Stack Trace:');
      buffer.writeln('    ${stackTrace.toString().replaceAll('\n', '\n    ')}');
    }
    
    return buffer.toString();
  }
  
  @override
  bool operator ==(Object other) {
    return other is DbError &&
        other.type == type &&
        other.message == message &&
        other.context == context &&
        other.cause == cause;
  }
  
  @override
  int get hashCode {
    return Object.hash(type, message, context, cause);
  }
}