import 'package:dartz/dartz.dart';

import '../errors/failures.dart';

/// Abstract base class for all use cases in the application.
///
/// [Type] - The return type on success.
/// [Params] - The input parameters type. Use [NoParams] for parameterless use cases.
///
/// All use cases return [Either<Failure, Type>] to enforce explicit error handling.
abstract class UseCase<Type, Params> {
  Future<Either<Failure, Type>> call(Params params);
}

/// Marker class for use cases that require no parameters.
class NoParams {
  const NoParams();
}