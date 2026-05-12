import 'package:equatable/equatable.dart';

import '../../../../../services/app_database.dart';

/// Full session entity for detail views.
///
/// Contains the complete session data including full transcription text,
/// refined text, and all metadata.
class SessionEntity extends Equatable {
  /// Unique session identifier (ULID).
  final String id;

  /// ISO 639-1 language code (e.g., 'en', 'fr', 'ar').
  final String languageCode;

  /// Session creation timestamp (UTC).
  final DateTime createdAt;

  /// Last update timestamp (UTC).
  final DateTime updatedAt;

  /// Full accumulated transcription text.
  final String transcribedText;

  /// LLM-refined text (null if not refined).
  final String? refinedText;

  /// Absolute path to the session's audio file.
  final String audioFilePath;

  /// Duration in milliseconds.
  final int durationMs;

  /// Current session status.
  final SessionStatus status;

  /// Creates a [SessionEntity].
  const SessionEntity({
    required this.id,
    required this.languageCode,
    required this.createdAt,
    required this.updatedAt,
    required this.transcribedText,
    this.refinedText,
    required this.audioFilePath,
    required this.durationMs,
    required this.status,
  });

  /// Creates a copy with updated fields.
  SessionEntity copyWith({
    String? id,
    String? languageCode,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? transcribedText,
    String? refinedText,
    String? audioFilePath,
    int? durationMs,
    SessionStatus? status,
  }) {
    return SessionEntity(
      id: id ?? this.id,
      languageCode: languageCode ?? this.languageCode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      transcribedText: transcribedText ?? this.transcribedText,
      refinedText: refinedText ?? this.refinedText,
      audioFilePath: audioFilePath ?? this.audioFilePath,
      durationMs: durationMs ?? this.durationMs,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [
        id,
        languageCode,
        createdAt,
        updatedAt,
        transcribedText,
        refinedText,
        audioFilePath,
        durationMs,
        status,
      ];
}
