import 'package:equatable/equatable.dart';

/// Configuration options for exporting a dictation session.
///
/// Controls what content is included in the exported document
/// and how it should be formatted.
class ExportOptionsEntity extends Equatable {
  /// Whether to use the LLM-refined text (if available).
  /// If `true` and refined text exists, it will be used as the primary content.
  /// If `false` or no refined text exists, the original transcription is used.
  final bool useRefinedText;

  /// Whether to include metadata section (date, language, duration).
  final bool includeMetadata;

  /// Optional custom filename override (without extension).
  /// If not provided, a default name based on the session ID is used.
  final String? customFilename;

  /// Creates [ExportOptionsEntity].
  const ExportOptionsEntity({
    this.useRefinedText = true,
    this.includeMetadata = true,
    this.customFilename,
  });

  /// Creates a copy with optionally updated fields.
  ExportOptionsEntity copyWith({
    bool? useRefinedText,
    bool? includeMetadata,
    String? customFilename,
  }) {
    return ExportOptionsEntity(
      useRefinedText: useRefinedText ?? this.useRefinedText,
      includeMetadata: includeMetadata ?? this.includeMetadata,
      customFilename: customFilename ?? this.customFilename,
    );
  }

  @override
  List<Object?> get props => [useRefinedText, includeMetadata, customFilename];

  @override
  String toString() =>
      'ExportOptionsEntity(useRefinedText: $useRefinedText, '
      'includeMetadata: $includeMetadata, customFilename: $customFilename)';
}

/// Lightweight session entity for export operations.
///
/// Encapsulates all session data needed for export without
/// depending on the database layer directly.
class SessionEntity extends Equatable {
  /// The session ID (ULID).
  final String id;

  /// ISO 639-1 language code.
  final String languageCode;

  /// Session creation timestamp (UTC).
  final DateTime createdAt;

  /// Last update timestamp (UTC).
  final DateTime updatedAt;

  /// Full accumulated transcription text.
  final String transcribedText;

  /// LLM-refined text (nullable).
  final String? refinedText;

  /// Absolute path to the session audio file.
  final String audioFilePath;

  /// Duration in milliseconds.
  final int durationMs;

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
  });

  /// Creates from the database [Session] object.
  factory SessionEntity.fromDatabase(dynamic session) {
    return SessionEntity(
      id: session.id,
      languageCode: session.languageCode,
      createdAt: session.createdAt,
      updatedAt: session.updatedAt,
      transcribedText: session.transcribedText,
      refinedText: session.refinedText,
      audioFilePath: session.audioFilePath,
      durationMs: session.durationMs,
    );
  }

  /// The effective text to use for export based on options.
  String getEffectiveText({bool preferRefined = true}) {
    if (preferRefined && refinedText != null && refinedText!.isNotEmpty) {
      return refinedText!;
    }
    return transcribedText;
  }

  /// Whether this session has refined text available.
  bool get hasRefinedText => refinedText != null && refinedText!.isNotEmpty;

  /// Formatted duration string (e.g., "5:32").
  String get formattedDuration {
    final seconds = durationMs ~/ 1000;
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  /// Human-readable language name.
  String get languageName {
    switch (languageCode.toLowerCase()) {
      case 'ar':
        return 'Arabic';
      case 'fr':
        return 'French';
      case 'en':
      default:
        return 'English';
    }
  }

  /// Whether the text is in an RTL language.
  bool get isRtl => languageCode.toLowerCase() == 'ar';

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
      ];

  @override
  String toString() => 'SessionEntity(id: $id, language: $languageCode, '
      'duration: ${formattedDuration})';
}
