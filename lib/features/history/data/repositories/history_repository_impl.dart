import 'dart:io';

import 'package:clipboard/clipboard.dart';
import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/session_entity.dart';
import '../../domain/entities/session_summary_entity.dart';
import '../../domain/repositories/i_history_repository.dart';
import '../datasources/local/history_local_datasource.dart';
import '../models/session_summary_model.dart';

/// Implementation of [IHistoryRepository] using Drift database and filesystem.
///
/// Handles all history data operations including:
/// - Querying sessions from the local Drift database
/// - Searching sessions by transcription content
/// - Deleting sessions and their associated audio files
/// - Copying text to the system clipboard
@Singleton(as: IHistoryRepository)
class HistoryRepositoryImpl implements IHistoryRepository {
  final HistoryLocalDatasource _datasource;
  final Logger _logger;

  const HistoryRepositoryImpl(
    this._datasource,
    this._logger,
  );

  @override
  Future<Either<Failure, List<SessionSummaryEntity>>> getAllSessions() async {
    try {
      final sessions = await _datasource.getAllSessions();
      final summaries = sessions.map(SessionSummaryModel.fromDrift).toList();
      return Right(summaries);
    } on DatabaseException catch (e) {
      _logger.e('Database error loading sessions', error: e);
      return Left(CacheFailure('Failed to load sessions: ${e.message}'));
    } catch (e, st) {
      _logger.e('Unexpected error loading sessions', error: e, stackTrace: st);
      return Left(UnexpectedFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, List<SessionSummaryEntity>>> searchSessions(String query) async {
    try {
      if (query.trim().isEmpty) {
        return getAllSessions();
      }
      final sessions = await _datasource.searchSessions(query.trim());
      final summaries = sessions.map(SessionSummaryModel.fromDrift).toList();
      return Right(summaries);
    } on DatabaseException catch (e) {
      _logger.e('Database error searching sessions', error: e);
      return Left(CacheFailure('Failed to search sessions: ${e.message}'));
    } catch (e, st) {
      _logger.e('Unexpected error searching sessions', error: e, stackTrace: st);
      return Left(UnexpectedFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, SessionEntity>> getSessionDetail(String id) async {
    try {
      final session = await _datasource.getSession(id);
      if (session == null) {
        return Left(CacheFailure('Session not found: $id'));
      }

      final entity = SessionEntity(
        id: session.id,
        languageCode: session.languageCode,
        createdAt: session.createdAt,
        updatedAt: session.updatedAt,
        transcribedText: session.transcribedText,
        refinedText: session.refinedText,
        audioFilePath: session.audioFilePath,
        durationMs: session.durationMs,
        status: SessionStatus.values[
          session.status.clamp(0, SessionStatus.values.length - 1)
        ],
      );
      return Right(entity);
    } on DatabaseException catch (e) {
      _logger.e('Database error loading session detail', error: e);
      return Left(CacheFailure('Failed to load session detail: ${e.message}'));
    } catch (e, st) {
      _logger.e('Unexpected error loading session detail', error: e, stackTrace: st);
      return Left(UnexpectedFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteSession(String id) async {
    try {
      // First get the session to find the audio file path
      final session = await _datasource.getSession(id);
      if (session == null) {
        return Left(CacheFailure('Session not found: $id'));
      }

      // Delete from database first (cascades to chunks)
      await _datasource.deleteSession(id);

      // Then delete the audio file
      try {
        final audioFile = File(session.audioFilePath);
        if (await audioFile.exists()) {
          await audioFile.delete();
          _logger.i('Deleted audio file: ${session.audioFilePath}');
        }
      } catch (e) {
        // Log but don't fail — the DB record is already deleted
        _logger.w('Failed to delete audio file: $e');
      }

      return const Right(unit);
    } on DatabaseException catch (e) {
      _logger.e('Database error deleting session', error: e);
      return Left(CacheFailure('Failed to delete session: ${e.message}'));
    } catch (e, st) {
      _logger.e('Unexpected error deleting session', error: e, stackTrace: st);
      return Left(UnexpectedFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, String>> getSessionAudioPath(String id) async {
    try {
      final session = await _datasource.getSession(id);
      if (session == null) {
        return Left(CacheFailure('Session not found: $id'));
      }
      return Right(session.audioFilePath);
    } on DatabaseException catch (e) {
      _logger.e('Database error getting audio path', error: e);
      return Left(CacheFailure('Failed to get audio path: ${e.message}'));
    } catch (e, st) {
      _logger.e('Unexpected error getting audio path', error: e, stackTrace: st);
      return Left(UnexpectedFailure('Unexpected error: $e'));
    }
  }

  @override
  Future<Either<Failure, Unit>> copyTextToClipboard(String text) async {
    try {
      await FlutterClipboard.copy(text);
      return const Right(unit);
    } catch (e, st) {
      _logger.e('Failed to copy to clipboard', error: e, stackTrace: st);
      return Left(UnexpectedFailure('Failed to copy to clipboard: $e'));
    }
  }
}
