import 'package:drift/drift.dart';

import '../../../../services/app_database.dart';
import '../../domain/entities/session_entity.dart';

/// Data model for [SessionEntity] that adds serialization capabilities.
///
/// Extends [SessionEntity] with factory methods for converting to/from
/// JSON and Drift database rows. This is the data layer representation
/// that bridges between the domain entity and the database.
class SessionModel extends SessionEntity {
  /// Creates a session model with all fields.
  const SessionModel({
    required super.id,
    required super.languageCode,
    required super.createdAt,
    required super.updatedAt,
    required super.transcribedText,
    super.refinedText,
    required super.audioFilePath,
    required super.durationMs,
    required super.status,
  });

  /// Creates a [SessionModel] from a [SessionEntity] (copy constructor).
  factory SessionModel.fromEntity(SessionEntity entity) {
    return SessionModel(
      id: entity.id,
      languageCode: entity.languageCode,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      transcribedText: entity.transcribedText,
      refinedText: entity.refinedText,
      audioFilePath: entity.audioFilePath,
      durationMs: entity.durationMs,
      status: entity.status,
    );
  }

  /// Creates a [SessionModel] from a Drift [Session] database row.
  ///
  /// Maps the integer status field to the [SessionStatus] enum.
  factory SessionModel.fromDrift(Session driftSession) {
    return SessionModel(
      id: driftSession.id,
      languageCode: driftSession.languageCode,
      createdAt: driftSession.createdAt,
      updatedAt: driftSession.updatedAt,
      transcribedText: driftSession.transcribedText,
      refinedText: driftSession.refinedText,
      audioFilePath: driftSession.audioFilePath,
      durationMs: driftSession.durationMs,
      status: SessionStatus.values[driftSession.status.clamp(0, SessionStatus.values.length - 1)],
    );
  }

  /// Converts this model to a Drift [SessionsCompanion] for database insertion.
  ///
  /// Used when creating or updating a session in the database.
  SessionsCompanion toDriftCompanion() {
    return SessionsCompanion(
      id: Value(id),
      languageCode: Value(languageCode),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      transcribedText: Value(transcribedText),
      refinedText: Value(refinedText),
      audioFilePath: Value(audioFilePath),
      durationMs: Value(durationMs),
      status: Value(status.index),
    );
  }

  /// Creates a [SessionModel] from a JSON map.
  ///
  /// Used for serialization (e.g., exporting session data).
  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      id: json['id'] as String,
      languageCode: json['languageCode'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      transcribedText: json['transcribedText'] as String? ?? '',
      refinedText: json['refinedText'] as String?,
      audioFilePath: json['audioFilePath'] as String,
      durationMs: json['durationMs'] as int? ?? 0,
      status: SessionStatus.values[
        (json['status'] as int? ?? 0).clamp(0, SessionStatus.values.length - 1)],
    );
  }

  /// Converts this model to a JSON map.
  ///
  /// Used for serialization (e.g., exporting session data).
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'languageCode': languageCode,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'transcribedText': transcribedText,
      'refinedText': refinedText,
      'audioFilePath': audioFilePath,
      'durationMs': durationMs,
      'status': status.index,
    };
  }

  @override
  SessionModel copyWith({
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
    return SessionModel(
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
}
