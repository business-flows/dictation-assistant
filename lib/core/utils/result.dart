import 'package:dartz/dartz.dart';

import '../errors/failures.dart';

/// Convenience type alias for operation results.
///
/// Use [Result<T>] as the return type for any operation that can fail.
/// Success: [Right] wrapping the value.
/// Failure: [Left] wrapping a [Failure].
type Result<T> = Either<Failure, T>;

/// Extension methods for cleaner Result handling.
extension ResultExtensions<T> on Result<T> {
  /// Execute [onSuccess] if Right, [onFailure] if Left.
  R fold<R>(R Function(Failure failure) onFailure, R Function(T value) onSuccess) {
    return fold(onFailure, onSuccess);
  }

  /// Get the success value or null.
  T? getOrNull() => fold((_) => null, (value) => value);

  /// Get the failure or null.
  Failure? failureOrNull() => fold((f) => f, (_) => null);

  /// Whether the result is a success.
  bool get isSuccess => fold((_) => false, (_) => true);

  /// Whether the result is a failure.
  bool get isFailure => fold((_) => true, (_) => false);
}