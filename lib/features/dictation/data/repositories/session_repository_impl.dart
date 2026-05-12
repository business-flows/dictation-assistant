import 'dart:async';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/audio_file_naming.dart';
import '../../../../core/utils/ulid_generator.dart';
import '../../domain/entities/session_entity.dart';
import '../../domain/repositories/i_session_repository.dart';
import '../datasources/local/session_local_datasource.dart';
import '../models/session_model.dart';

/// Concrete implementation of [ISessionRepository] using Drift database.
///
/// Delegates all database operations to [SessionLocalDataSource] and
/// handles error mapping from exceptions to [Failure] types. All methods
/// catch exceptions and return [Left<Failure>] to enforce explicit error handling.
///
/// Session IDs are ULIDs generated at creation time using [UlidGenerator].
@LazySingleton(as: ISessionRepository)
class SessionRepositoryImpl implements ISessionRepository {
  final SessionLocalDataSource _dataSource;
  final Logger _logger;

  /// Creates the session repository.
  SessionRepositoryImpl({
    required SessionLocalDataSource dataSource,
    required Logger logger,
  })  : _dataSource = dataSource,
        _logger = logger;

  @override
  Future<Either<Failure, SessionEntity>> createSession(String languageCode) async {
    try {
      // Generate ULID and audio path
      final sessionData = AudioFileNaming.createSession();
      final now = DateTime.now().toUtc();

      final session = SessionModel(
        id: sessionData.sessionId,
        languageCode: languageCode,
        createdAt: now,
        updatedAt: now,
        transcribedText: '',
        refinedText: null,
        audioFilePath: sessionData.audioPath,
        durationMs: 0,
        status: SessionStatus.recording,
      );

      await _dataSource.insertSession(session.toDriftCompanion());

      _logger.i('SessionRepository: Created session ${session.id} with language $languageCode');
      return Right(session);
    } on DatabaseException catch (e) {
      _logger.e('SessionRepository: Database error creating session', error: e);
      return Left(CacheFailure('Failed to create session: ${e.message}', code: e.code));
    } catch (e, stackTrace) {
      _logger.e('SessionRepository: Unexpected error creating session', error: e, stackTrace: stackTrace);
      return Left(UnexpectedFailure('Failed to create session: $e'));
    }
  }

  @override
  Future<Either<Failure, SessionEntity>> getSession(String id) async {
    try {
      final driftSession = await _dataSource.getSession(id);

      if (driftSession == null) {
        return Left(CacheFailure('Session not found: $id', code: 'SESSION_NOT_FOUND'));
      }

      final session = SessionModel.fromDrift(driftSession);
      return Right(session);
    } on DatabaseException catch (e) {
      _logger.e('SessionRepository: Database error getting session $id', error: e);
      return Left(CacheFailure('Failed to retrieve session: ${e.message}', code: e.code));
    } catch (e, stackTrace) {
      _logger.e('SessionRepository: Unexpected error getting session $id', error: e, stackTrace: stackTrace);
      return Left(UnexpectedFailure('Failed to retrieve session: $e'));
    }
  }

  @override
  Future<Either<Failure, SessionEntity>> updateSession(SessionEntity session) async {
    try {
      final model = SessionModel.fromEntity(session);
      final updated = model.copyWith(updatedAt: DateTime.now().toUtc());

      await _dataSource.updateSession(updated.id, updated.toDriftCompanion());

      _logger.d('SessionRepository: Updated session ${session.id}');
      return Right(updated);
    } on DatabaseException catch (e) {
      _logger.e('SessionRepository: Database error updating session ${session.id}', error: e);
      return Left(CacheFailure('Failed to update session: ${e.message}', code: e.code));
    } catch (e, stackTrace) {
      _logger.e('SessionRepository: Unexpected error updating session', error: e, stackTrace: stackTrace);
      return Left(UnexpectedFailure('Failed to update session: $e'));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteSession(String id) async {
    try {
      // Get the session first to find and clean up its audio file
      final sessionResult = await getSession(id);
      final session = sessionResult.fold((_) => null, (s) => s);

      // Delete from database (cascades to chunks)
      final deleted = await _dataSource.deleteSession(id);

      if (deleted == 0) {
        return Left(CacheFailure('Session not found: $id', code: 'SESSION_NOT_FOUND'));
      }

      // Clean up the audio file
      if (session != null) {
        try {
          final file = File(session.audioFilePath);
          if (await file.exists()) {
            await file.delete();
            _logger.d('SessionRepository: Deleted audio file ${session.audioFilePath}');
          }
        } catch (e) {
          _logger.w('SessionRepository: Failed to delete audio file for session $id: $e');
          // Don't fail the operation if file cleanup fails
        }
      }

      _logger.i('SessionRepository: Deleted session $id');
      return const Right(unit);
    } on DatabaseException catch (e) {
      _logger.e('SessionRepository: Database error deleting session $id', error: e);
      return Left(CacheFailure('Failed to delete session: ${e.message}', code: e.code));
    } catch (e, stackTrace) {
      _logger.e('SessionRepository: Unexpected error deleting session', error: e, stackTrace: stackTrace);
      return Left(UnexpectedFailure('Failed to delete session: $e'));
    }
  }

  @override
  Future<Either<Failure, List<SessionEntity>>> getAllSessions() async {
    try {
      final driftSessions = await _dataSource.getAllSessions();
      final sessions = driftSessions.map(SessionModel.fromDrift).toList();
      return Right(sessions);
    } on DatabaseException catch (e) {
      _logger.e('SessionRepository: Database error getting all sessions', error: e);
      return Left(CacheFailure('Failed to retrieve sessions: ${e.message}', code: e.code));
    } catch (e, stackTrace) {
      _logger.e('SessionRepository: Unexpected error getting all sessions', error: e, stackTrace: stackTrace);
      return Left(UnexpectedFailure('Failed to retrieve sessions: $e'));
    }
  }

  @override
  Stream<Either<Failure, List<SessionEntity>>> watchAllSessions() {
    return _dataSource.watchAllSessions().map((driftSessions) {
      try {
        final sessions = driftSessions.map(SessionModel.fromDrift).toList();
        return Right<Failure, List<SessionEntity>>(sessions);
      } catch (e, stackTrace) {
        _logger.e('SessionRepository: Error mapping sessions', error: e, stackTrace: stackTrace);
        return Left<Failure, List<SessionEntity>>(
          CacheFailure('Failed to process sessions stream: $e'),
        );
      }
    }).handleError((Object e, StackTrace st) {
      _logger.e('SessionRepository: Stream error', error: e, stackTrace: st);
      return Left<Failure, List<SessionEntity>>(
        CacheFailure('Session stream error: $e'),
      );
    });
  }

  @override
  Future<Either<Failure, Unit>> updateTranscribedText(String id, String text) async {
    try {
      final updated = await _dataSource.updateTranscribedText(id, text);

      if (updated == 0) {
        return Left(CacheFailure('Session not found: $id', code: 'SESSION_NOT_FOUND'));
      }

      _logger.d('SessionRepository: Updated transcribed text for session $id (${text.length} chars)');
      return const Right(unit);
    } on DatabaseException catch (e) {
      _logger.e('SessionRepository: Database error updating text for $id', error: e);
      return Left(CacheFailure('Failed to update transcribed text: ${e.message}', code: e.code));
    } catch (e, stackTrace) {
      _logger.e('SessionRepository: Unexpected error updating text', error: e, stackTrace: stackTrace);
      return Left(UnexpectedFailure('Failed to update transcribed text: $e'));
    }
  }

  @override
  Future<Either<Failure, Unit>> updateRefinedText(String id, String? text) async {
    try {
      final updated = await _dataSource.updateRefinedText(id, text);

      if (updated == 0) {
        return Left(CacheFailure('Session not found: $id', code: 'SESSION_NOT_FOUND'));
      }

      _logger.d('SessionRepository: Updated refined text for session $id');
      return const Right(unit);
    } on DatabaseException catch (e) {
      _logger.e('SessionRepository: Database error updating refined text for $id', error: e);
      return Left(CacheFailure('Failed to update refined text: ${e.message}', code: e.code));
    } catch (e, stackTrace) {
      _logger.e('SessionRepository: Unexpected error updating refined text', error: e, stackTrace: stackTrace);
      return Left(UnexpectedFailure('Failed to update refined text: $e'));
    }
  }

  @override
  Future<Either<Failure, Unit>> finalizeSession(
    String id,
    SessionStatus status,
    int durationMs,
  ) async {
    try {
      final updated = await _dataSource.finalizeSession(id, status, durationMs);

      if (updated == 0) {
        return Left(CacheFailure('Session not found: $id', code: 'SESSION_NOT_FOUND'));
      }

      _logger.i('SessionRepository: Finalized session $id (status: $status, duration: ${durationMs}ms)');
      return const Right(unit);
    } on DatabaseException catch (e) {
      _logger.e('SessionRepository: Database error finalizing session $id', error: e);
      return Left(CacheFailure('Failed to finalize session: ${e.message}', code: e.code));
    } catch (e, stackTrace) {
      _logger.e('SessionRepository: Unexpected error finalizing session', error: e, stackTrace: stackTrace);
      return Left(UnexpectedFailure('Failed to finalize session: $e'));
    }
  }
}
