import 'package:equatable/equatable.dart';

import '../../../../services/app_database.dart';

/// Status of an audio chunk in the transcription pipeline.
///
/// Represents the processing lifecycle of a single audio chunk:
/// - [pending] - Chunk is queued but not yet being transcribed.
/// - [processing] - Chunk transcription is currently in progress.
/// - [completed] - Chunk was successfully transcribed.
/// - [error] - Chunk transcription failed.
enum ChunkStatus { pending, processing, completed, error }

/// Entity representing a single audio chunk within a dictation session.
///
/// Audio chunks are segments of a session's recording that are transcribed
/// independently. Chunks overlap by 0.5 seconds to ensure no words are lost
/// at boundaries. Each chunk contains its own transcription result.
///
/// Chunks are ordered by [chunkIndex] within their parent session.
class AudioChunkEntity extends Equatable {
  /// ULID primary key.
  final String id;

  /// Foreign key to the parent session's ULID.
  final String sessionId;

  /// Zero-based sequential index within the session.
  final int chunkIndex;

  /// Absolute path to the chunk's audio file (WAV format).
  final String filePath;

  /// Start time in milliseconds from the session start.
  final int startTimeMs;

  /// End time in milliseconds from the session start.
  final int endTimeMs;

  /// Transcription result for this chunk (empty until completed).
  final String transcription;

  /// Current processing status of this chunk.
  final ChunkStatus status;

  /// Creates a new audio chunk entity.
  const AudioChunkEntity({
    required this.id,
    required this.sessionId,
    required this.chunkIndex,
    required this.filePath,
    required this.startTimeMs,
    required this.endTimeMs,
    this.transcription = '',
    required this.status,
  });

  /// Creates a new chunk with updated fields.
  ///
  /// All fields default to their current values if not specified.
  AudioChunkEntity copyWith({
    String? id,
    String? sessionId,
    int? chunkIndex,
    String? filePath,
    int? startTimeMs,
    int? endTimeMs,
    String? transcription,
    ChunkStatus? status,
  }) {
    return AudioChunkEntity(
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

  @override
  List<Object?> get props => [
        id,
        sessionId,
        chunkIndex,
        filePath,
        startTimeMs,
        endTimeMs,
        transcription,
        status,
      ];

  @override
  String toString() {
    return 'AudioChunkEntity(id: $id, session: $sessionId, index: $chunkIndex, '
        'status: $status, start: ${startTimeMs}ms, end: ${endTimeMs}ms)';
  }
}
