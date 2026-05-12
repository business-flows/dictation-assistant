import 'package:equatable/equatable.dart';

/// Base failure class for the application.
/// All specific failures extend this class.
abstract class Failure extends Equatable {
  final String message;
  final String? code;

  const Failure(this.message, {this.code});

  @override
  List<Object?> get props => [message, code];
}

/// Server/LLM API failures.
class ServerFailure extends Failure {
  final int? statusCode;

  const ServerFailure(super.message, {this.statusCode, super.code});

  @override
  List<Object?> get props => [message, statusCode, code];
}

/// Cache/Database failures.
class CacheFailure extends Failure {
  const CacheFailure(super.message, {super.code});
}

/// Network connectivity failures.
class NetworkFailure extends Failure {
  const NetworkFailure(super.message, {super.code});
}

/// Permission failures (microphone, storage).
class PermissionFailure extends Failure {
  const PermissionFailure(super.message, {super.code});
}

/// Audio recording/processing failures.
class AudioFailure extends Failure {
  const AudioFailure(super.message, {super.code});
}

/// Transcription (whisper.cpp) failures.
class TranscriptionFailure extends Failure {
  final bool isRecoverable;

  const TranscriptionFailure(
    super.message, {
    this.isRecoverable = true,
    super.code,
  });

  @override
  List<Object?> get props => [message, isRecoverable, code];
}

/// Model management failures.
class ModelFailure extends Failure {
  const ModelFailure(super.message, {super.code});
}

/// Export/file generation failures.
class ExportFailure extends Failure {
  const ExportFailure(super.message, {super.code});
}

/// Validation/input failures.
class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {super.code});
}

/// Unexpected/unknown failures.
class UnexpectedFailure extends Failure {
  const UnexpectedFailure(super.message, {super.code});
}