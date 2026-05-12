import 'package:equatable/equatable.dart';

import '../../../../services/app_database.dart';

/// Status of a dictation session.
///
/// Represents the lifecycle stages of a recording session:
/// - [recording] - Session is actively recording audio.
/// - [paused] - Recording is paused (can be resumed).
/// - [completed] - Recording has been stopped and finalized.
enum SessionStatus { recording, paused, completed }

/// Entity representing a dictation session.
///
/// A session encompasses a single dictation recording from start to finish,
/// including the accumulated transcription text and associated metadata.
/// Sessions are identified by ULID for lexicographic sortability.
///
/// This is a plain Dart class with value semantics - modifications create
/// new instances via [copyWith].
class SessionEntity extends Equatable {
  /// ULID primary key (26 characters, lexicographically sortable).
  final String id;

  /// ISO 639-1 language code for transcription: 'en', 'fr', or 'ar'.
  final String languageCode;

  /// Session creation timestamp (UTC).
  final DateTime createdAt;

  /// Last update timestamp (UTC).
  final DateTime updatedAt;

  /// Full accumulated transcription text from all chunks.
  final String transcribedText;

  /// LLM-refined text (null until refinement is performed and accepted).
  final String? refinedText;

  /// Absolute path to the concatenated session audio file (WAV format).
  final String audioFilePath;

  /// Duration of the recording in milliseconds.
  final int durationMs;

  /// Current status of the session.
  final SessionStatus status;

  /// Creates a new session entity.
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

  /// Creates a new session with updated fields.
  ///
  /// All fields default to their current values if not specified.
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

  @override
  String toString() {
    return 'SessionEntity(id: $id, language: $languageCode, status: $status, '
        'duration: ${durationMs}ms)';
  }
}
