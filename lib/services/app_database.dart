import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../core/constants/app_constants.dart';

part 'app_database.g.dart';

/// Drift database definition for the Dictation Assistant app.
///
/// Tables:
/// - [Sessions]: Stores dictation session metadata and transcription text
/// - [AudioChunks]: Stores per-chunk transcription results
/// - [Settings]: Singleton table for app configuration
@DataClassName('Session')
class Sessions extends Table {
  /// ULID primary key (26 characters, lexicographically sortable)
  TextColumn get id => text().withLength(min: 26, max: 26)();

  /// ISO 639-1 language code: 'en', 'fr', or 'ar'
  TextColumn get languageCode => text().withLength(min: 2, max: 2)();

  /// Session creation timestamp (UTC)
  DateTimeColumn get createdAt => dateTime()();

  /// Last update timestamp (UTC)
  DateTimeColumn get updatedAt => dateTime()();

  /// Full accumulated transcription text
  TextColumn get transcribedText => text().withDefault(const Constant(''))();

  /// LLM-refined text (nullable until refinement is accepted)
  TextColumn get refinedText => text().nullable()();

  /// Absolute path to the concatenated session audio file
  TextColumn get audioFilePath => text()();

  /// Duration in milliseconds
  IntColumn get durationMs => integer().withDefault(const Constant(0))();

  /// Session status: 0=recording, 1=paused, 2=completed
  IntColumn get status => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'sessions';
}

/// Audio chunk table - one row per transcription chunk.
@DataClassName('AudioChunk')
class AudioChunks extends Table {
  /// ULID primary key
  TextColumn get id => text().withLength(min: 26, max: 26)();

  /// Foreign key to Sessions.id
  TextColumn get sessionId => text().withLength(min: 26, max: 26)();

  /// Zero-based sequential index within session
  IntColumn get chunkIndex => integer()();

  /// Path to chunk PCM/WAV file
  TextColumn get filePath => text()();

  /// Start time in ms from session start
  IntColumn get startTimeMs => integer()();

  /// End time in ms from session start
  IntColumn get endTimeMs => integer()();

  /// Transcription result for this chunk
  TextColumn get transcription => text().withDefault(const Constant(''))();

  /// Status: 0=pending, 1=processing, 2=completed, 3=error
  IntColumn get status => integer().withDefault(const Constant(0))();

  /// Confidence score (0.0-1.0), nullable
  RealColumn get confidence => real().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'audio_chunks';

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE',
  ];
}

/// Settings table (singleton - only ever one row).
@DataClassName('AppSetting')
class Settings extends Table {
  /// Single row identifier, always 1
  IntColumn get id => integer()();

  /// Default dictation language code
  TextColumn get defaultLanguage => text().withLength(min: 2, max: 2).withDefault(const Constant('en'))();

  /// Selected whisper model ID
  TextColumn get selectedModelId => text().withDefault(const Constant(AppConstants.defaultModelId))();

  /// LLM endpoint URL (nullable)
  TextColumn get llmEndpointUrl => text().nullable()();

  /// LLM model name (nullable)
  TextColumn get llmModelName => text().nullable()();

  /// LLM system prompt (nullable)
  TextColumn get llmSystemPrompt => text().nullable()();

  /// Auto-refine after each session
  BoolColumn get autoRefine => boolean().withDefault(const Constant(false))();

  /// Minimize to system tray (desktop only)
  BoolColumn get minimizeToTray => boolean().withDefault(const Constant(true))();

  /// Always on top (desktop only)
  BoolColumn get alwaysOnTop => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'settings';
}

/// Drift database class.
@DriftDatabase(tables: [Sessions, AudioChunks, Settings])
class AppDatabase extends _$AppDatabase {
  AppDatabase({QueryExecutor? executor}) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      // Insert default settings
      await into(settings).insertOnConflictUpdate(
        SettingsCompanion.insert(
          id: const Value(1),
          defaultLanguage: const Value('en'),
          selectedModelId: const Value(AppConstants.defaultModelId),
        ),
      );
    },
    onUpgrade: (Migrator m, int from, int to) async {
      // Simple migration: recreate all tables
      // In production, use step-by-step migrations
      for (final table in allTables) {
        await m.deleteTable(table.actualTableName);
      }
      await m.createAll();
    },
  );

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: AppConstants.databaseName,
      native: const DriftNativeOptions(),
    );
  }

  // ---- Session queries ----

  /// Watch all sessions ordered by creation time (newest first).
  Stream<List<Session>> watchAllSessions() {
    return (select(sessions)
      ..orderBy([(s) => OrderingTerm.desc(s.createdAt)]))
      .watch();
  }

  /// Get all sessions as a one-time query.
  Future<List<Session>> getAllSessions() {
    return (select(sessions)
      ..orderBy([(s) => OrderingTerm.desc(s.createdAt)]))
      .get();
  }

  /// Get a single session by ID.
  Future<Session?> getSession(String id) {
    return (select(sessions)..where((s) => s.id.equals(id))).getSingleOrNull();
  }

  /// Watch a single session.
  Stream<Session?> watchSession(String id) {
    return (select(sessions)..where((s) => s.id.equals(id))).watchSingleOrNull();
  }

  /// Insert a new session.
  Future<int> insertSession(SessionsCompanion session) {
    return into(sessions).insert(session);
  }

  /// Update session data.
  Future<bool> updateSession(String id, SessionsCompanion data) {
    return update(sessions).replace(data.copyWith(id: Value(id)));
  }

  /// Update just the transcribed text.
  Future<int> updateSessionText(String id, String text) {
    return (update(sessions)..where((s) => s.id.equals(id)))
        .write(SessionsCompanion(transcribedText: Value(text), updatedAt: Value(DateTime.now().toUtc())));
  }

  /// Update refined text.
  Future<int> updateRefinedText(String id, String? refinedText) {
    return (update(sessions)..where((s) => s.id.equals(id)))
        .write(SessionsCompanion(refinedText: Value(refinedText), updatedAt: Value(DateTime.now().toUtc())));
  }

  /// Update session status and duration.
  Future<int> finalizeSession(String id, SessionStatus status, int durationMs) {
    return (update(sessions)..where((s) => s.id.equals(id)))
        .write(SessionsCompanion(
          status: Value(status.index),
          durationMs: Value(durationMs),
          updatedAt: Value(DateTime.now().toUtc()),
        ));
  }

  /// Delete a session (cascades to chunks via FK).
  Future<int> deleteSession(String id) {
    return (delete(sessions)..where((s) => s.id.equals(id))).go();
  }

  /// Search sessions by transcription content.
  Future<List<Session>> searchSessions(String query) {
    final likeQuery = '%${query.toLowerCase()}%';
    return (select(sessions)
      ..where((s) => s.transcribedText.lowerLike(likeQuery))
      ..orderBy([(s) => OrderingTerm.desc(s.createdAt)]))
      .get();
  }

  // ---- Chunk queries ----

  /// Get all chunks for a session.
  Future<List<AudioChunk>> getChunksForSession(String sessionId) {
    return (select(audioChunks)
      ..where((c) => c.sessionId.equals(sessionId))
      ..orderBy([(c) => OrderingTerm.asc(c.chunkIndex)]))
      .get();
  }

  /// Insert a chunk.
  Future<int> insertChunk(AudioChunksCompanion chunk) {
    return into(audioChunks).insert(chunk);
  }

  /// Update chunk transcription.
  Future<int> updateChunkTranscription(String id, String transcription, double? confidence) {
    return (update(audioChunks)..where((c) => c.id.equals(id)))
        .write(AudioChunksCompanion(
          transcription: Value(transcription),
          confidence: Value(confidence),
          status: const Value(2), // completed
        ));
  }

  /// Update chunk status.
  Future<int> updateChunkStatus(String id, ChunkStatus status) {
    return (update(audioChunks)..where((c) => c.id.equals(id)))
        .write(AudioChunksCompanion(status: Value(status.index)));
  }

  // ---- Settings queries ----

  /// Get settings (singleton).
  Future<AppSetting?> getSettings() {
    return (select(settings)..where((s) => s.id.equals(1))).getSingleOrNull();
  }

  /// Watch settings.
  Stream<AppSetting?> watchSettings() {
    return (select(settings)..where((s) => s.id.equals(1))).watchSingleOrNull();
  }

  /// Update settings.
  Future<int> updateSettings(SettingsCompanion data) {
    return into(settings).insertOnConflictUpdate(data.copyWith(id: const Value(1)));
  }
}

/// Session status enum mapping.
enum SessionStatus { recording, paused, completed }

/// Chunk status enum mapping.
enum ChunkStatus { pending, processing, completed, error }