import 'package:equatable/equatable.dart';

import '../../../dictation/domain/entities/session_entity.dart' show SessionStatus;

/// Lightweight entity for displaying session summaries in history list views.
///
/// Contains only essential metadata needed for list display, not the full
/// transcription text. Use [SessionEntity] (from the session domain) for
/// the full session detail view.
class SessionSummaryEntity extends Equatable {
  /// Unique session identifier (ULID).
  final String id;

  /// ISO 639-1 language code (e.g., 'en', 'fr', 'ar').
  final String languageCode;

  /// Session creation timestamp (UTC).
  final DateTime createdAt;

  /// Duration in milliseconds.
  final int durationMs;

  /// Preview text — first ~100 characters of transcription.
  final String previewText;

  /// Whether the session has LLM-refined text.
  final bool hasRefinedText;

  /// Absolute path to the session's audio file.
  final String audioFilePath;

  /// Current session status.
  final SessionStatus status;

  /// Creates a [SessionSummaryEntity].
  const SessionSummaryEntity({
    required this.id,
    required this.languageCode,
    required this.createdAt,
    required this.durationMs,
    required this.previewText,
    required this.hasRefinedText,
    required this.audioFilePath,
    required this.status,
  });

  /// Creates a copy with updated fields.
  SessionSummaryEntity copyWith({
    String? id,
    String? languageCode,
    DateTime? createdAt,
    int? durationMs,
    String? previewText,
    bool? hasRefinedText,
    String? audioFilePath,
    SessionStatus? status,
  }) {
    return SessionSummaryEntity(
      id: id ?? this.id,
      languageCode: languageCode ?? this.languageCode,
      createdAt: createdAt ?? this.createdAt,
      durationMs: durationMs ?? this.durationMs,
      previewText: previewText ?? this.previewText,
      hasRefinedText: hasRefinedText ?? this.hasRefinedText,
      audioFilePath: audioFilePath ?? this.audioFilePath,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [
        id,
        languageCode,
        createdAt,
        durationMs,
        previewText,
        hasRefinedText,
        audioFilePath,
        status,
      ];
}
