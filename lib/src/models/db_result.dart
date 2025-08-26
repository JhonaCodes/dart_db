// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║                              DB RESULT                                       ║
// ║                    Type-Safe Result Pattern for Backend                      ║
// ║══════════════════════════════════════════════════════════════════════════════║
// ║                                                                              ║
// ║  Author: JhonaCode (Jhonatan Ortiz)                                         ║
// ║  Contact: info@jhonacode.com                                                 ║
// ║  Module: db_result.dart                                                      ║
// ║  Purpose: Type-safe error handling for database operations                  ║
// ║                                                                              ║
// ║  Description:                                                                ║
// ║    Provides a simple Result<T, E> type for type-safe error handling        ║
// ║    without exceptions. Perfect for backend applications where reliable      ║
// ║    error handling is critical.                                              ║
// ║                                                                              ║
// ║  Features:                                                                   ║
// ║    • Type-safe error handling                                                ║
// ║    • Pattern matching with when()                                            ║
// ║    • Zero runtime exceptions                                                 ║
// ║    • Lightweight and fast                                                    ║
// ║                                                                              ║
// ╚══════════════════════════════════════════════════════════════════════════════╝

/// A type-safe result type for database operations
/// 
/// Represents either a successful result ([Ok]) containing a value of type [T],
/// or a failure ([Err]) containing an error of type [E].
/// 
/// Example:
/// ```dart
/// DbResult<String, DbError> result = database.get('key');
/// result.when(
///   ok: (value) => print('Got: $value'),
///   err: (error) => print('Error: $error'),
/// );
/// ```
sealed class DbResult<T, E> {
  const DbResult();
  
  /// Pattern matching method for handling both success and error cases
  /// 
  /// Forces explicit handling of both cases, preventing unhandled errors.
  R when<R>({
    required R Function(T value) ok,
    required R Function(E error) err,
  });
  
  /// Returns true if this is a successful result
  bool get isOk => this is Ok<T, E>;
  
  /// Returns true if this is an error result  
  bool get isErr => this is Err<T, E>;
  
  /// Returns the success value if present, null otherwise
  T? get okOrNull => isOk ? (this as Ok<T, E>).value : null;
  
  /// Returns the error if present, null otherwise
  E? get errOrNull => isErr ? (this as Err<T, E>).error : null;
  
  /// Returns the success value or throws the error
  T unwrap() {
    return when(
      ok: (value) => value,
      err: (error) => throw Exception('Unwrap called on error result: $error'),
    );
  }
  
  /// Returns the success value or the provided default
  T unwrapOr(T defaultValue) {
    return when(
      ok: (value) => value, 
      err: (_) => defaultValue,
    );
  }
  
  /// Maps the success value to a new type
  DbResult<R, E> map<R>(R Function(T value) mapper) {
    return when(
      ok: (value) => Ok(mapper(value)),
      err: (error) => Err(error),
    );
  }
  
  /// Maps the error to a new type
  DbResult<T, R> mapErr<R>(R Function(E error) mapper) {
    return when(
      ok: (value) => Ok(value),
      err: (error) => Err(mapper(error)),
    );
  }
}

/// Represents a successful result containing a value
class Ok<T, E> extends DbResult<T, E> {
  final T value;
  const Ok(this.value);
  
  @override
  R when<R>({
    required R Function(T value) ok,
    required R Function(E error) err,
  }) => ok(value);
  
  @override
  String toString() => 'Ok($value)';
  
  @override
  bool operator ==(Object other) => other is Ok<T, E> && other.value == value;
  
  @override
  int get hashCode => value.hashCode;
}

/// Represents a failed result containing an error
class Err<T, E> extends DbResult<T, E> {
  final E error;
  const Err(this.error);
  
  @override
  R when<R>({
    required R Function(T value) ok,
    required R Function(E error) err,
  }) => err(error);
  
  @override
  String toString() => 'Err($error)';
  
  @override
  bool operator ==(Object other) => other is Err<T, E> && other.error == error;
  
  @override
  int get hashCode => error.hashCode;
}