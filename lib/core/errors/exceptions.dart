/// Base exception for the application.
class AppException implements Exception {
  final String message;
  final String? code;

  const AppException(this.message, {this.code});

  @override
  String toString() => 'AppException: $message${code != null ? ' ($code)' : ''}';
}

class DatabaseException extends AppException {
  const DatabaseException(super.message, {super.code});
}

class AudioRecordingException extends AppException {
  const AudioRecordingException(super.message, {super.code});
}

class TranscriptionException extends AppException {
  final bool isRecoverable;

  const TranscriptionException(
    super.message, {
    this.isRecoverable = true,
    super.code,
  });
}

class ModelLoadException extends AppException {
  const ModelLoadException(super.message, {super.code});
}

class ModelDownloadException extends AppException {
  const ModelDownloadException(super.message, {super.code});
}

class LLMApiException extends AppException {
  final int? statusCode;

  const LLMApiException(super.message, {this.statusCode, super.code});
}

class ExportException extends AppException {
  const ExportException(super.message, {super.code});
}

class PermissionException extends AppException {
  const PermissionException(super.message, {super.code});
}