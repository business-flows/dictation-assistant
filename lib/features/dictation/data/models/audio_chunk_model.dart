import 'package:drift/drift.dart';

import '../../../../services/app_database.dart';
import '../../domain/entities/audio_chunk_entity.dart';

/// Data model for [AudioChunkEntity] that adds serialization capabilities.
///
/// Extends [AudioChunkEntity] with factory methods for converting to/from
/// JSON and Drift database rows. This is the data layer representation
/// that bridges between the domain entity and the database.
class AudioChunkModel extends AudioChunkEntity {
  /// Creates an audio chunk model with all fields.
  const AudioChunkModel({
    required super.id,
    required super.sessionId,
    required super.chunkIndex,
    required super.filePath,
    required super.startTimeMs,
    required super.endTimeMs,
    super.transcription,
    required super.status,
  });

  /// Creates an [AudioChunkModel] from an [AudioChunkEntity] (copy constructor).
  factory AudioChunkModel.fromEntity(AudioChunkEntity entity) {
    return AudioChunkModel(
      id: entity.id,
      sessionId: entity.sessionId,
      chunkIndex: entity.chunkIndex,
      filePath: entity.filePath,
      startTimeMs: entity.startTimeMs,
      endTimeMs: entity.endTimeMs,
      transcription: entity.transcription,
      status: entity.status,
    );
  }

  /// Creates an [AudioChunkModel] from a Drift [AudioChunk] database row.
  ///
  /// Maps the integer status field to the [ChunkStatus] enum.
  factory AudioChunkModel.fromDrift(AudioChunk driftChunk) {
    return AudioChunkModel(
      id: driftChunk.id,
      sessionId: driftChunk.sessionId,
      chunkIndex: driftChunk.chunkIndex,
      filePath: driftChunk.filePath,
      startTimeMs: driftChunk.startTimeMs,
      endTimeMs: driftChunk.endTimeMs,
      transcription: driftChunk.transcription,
      status: ChunkStatus.values[driftChunk.status.clamp(0, ChunkStatus.values.length - 1)],
    );
  }

  /// Converts this model to a Drift [AudioChunksCompanion] for database insertion.
  ///
  /// Used when creating or updating a chunk in the database.
  AudioChunksCompanion toDriftCompanion() {
    return AudioChunksCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      chunkIndex: Value(chunkIndex),
      filePath: Value(filePath),
      startTimeMs: Value(startTimeMs),
      endTimeMs: Value(endTimeMs),
      transcription: Value(transcription),
      status: Value(status.index),
    );
  }

  /// Creates an [AudioChunkModel] from a JSON map.
  ///
  /// Used for serialization (e.g., exporting chunk data).
  factory AudioChunkModel.fromJson(Map<String, dynamic> json) {
    return AudioChunkModel(
      id: json['id'] as String,
      sessionId: json['sessionId'] as String,
      chunkIndex: json['chunkIndex'] as int,
      filePath: json['filePath'] as String,
      startTimeMs: json['startTimeMs'] as int,
      endTimeMs: json['endTimeMs'] as int,
      transcription: json['transcription'] as String? ?? '',
      status: ChunkStatus.values[
        (json['status'] as int? ?? 0).clamp(0, ChunkStatus.values.length - 1)],
    );
  }

  /// Converts this model to a JSON map.
  ///
  /// Used for serialization (e.g., exporting chunk data).
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sessionId': sessionId,
      'chunkIndex': chunkIndex,
      'filePath': filePath,
      'startTimeMs': startTimeMs,
      'endTimeMs': endTimeMs,
      'transcription': transcription,
      'status': status.index,
    };
  }

  @override
  AudioChunkModel copyWith({
    String? id,
    String? sessionId,
    int? chunkIndex,
    String? filePath,
    int? startTimeMs,
    int? endTimeMs,
    String? transcription,
    ChunkStatus? status,
  }) {
    return AudioChunkModel(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      chunkIndex: chunkIndex ?? this.chunkIndex,
      filePath: filePath ?? this.filePath,
      startTimeMs: startTimeMs ?? this.startTimeMs,
      endTimeMs: endTimeMs ?? this.endTimeMs,
      transcription: transcription ?? this.transcription,
      status: status ?? this.status,
    );
  }
}
