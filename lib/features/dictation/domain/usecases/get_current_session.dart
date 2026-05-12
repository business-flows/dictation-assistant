import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/session_entity.dart';
import '../repositories/i_session_repository.dart';

/// Parameters for getting the current/active session.
///
/// If [sessionId] is provided, retrieves that specific session.
/// If null, the caller should use [GetAllSessions] and filter.
class GetCurrentSessionParams {
  /// Optional session ID to retrieve.
  final String? sessionId;

  /// Creates get current session parameters.
  const GetCurrentSessionParams({this.sessionId});
}

/// Use case for retrieving the currently active dictation session.
///
/// When [sessionId] is provided, returns that specific session.
/// The caller is responsible for tracking which session is currently
/// active (typically the BLoC maintains this state).
///
/// For listing all sessions, use [GetAllSessions] instead.
@injectable
class GetCurrentSession implements UseCase<SessionEntity, GetCurrentSessionParams> {
  final ISessionRepository _sessionRepository;
  final Logger _logger;

  /// Creates the get current session use case.
  GetCurrentSession({
    required ISessionRepository sessionRepository,
    required Logger logger,
  })  : _sessionRepository = sessionRepository,
        _logger = logger;

  @override
  Future<Either<Failure, SessionEntity>> call(GetCurrentSessionParams params) async {
    try {
      if (params.sessionId == null || params.sessionId!.isEmpty) {
        return const Left(ValidationFailure(
          'No session ID provided. Start a dictation session first.',
          code: 'NO_ACTIVE_SESSION',
        ));
      }

      _logger.d('GetCurrentSession: Retrieving session ${params.sessionId}');

      final result = await _sessionRepository.getSession(params.sessionId!);

      return result.fold(
        (failure) {
          _logger.w('GetCurrentSession: Session not found: ${params.sessionId}');
          return Left(failure);
        },
        (session) {
          _logger.d('GetCurrentSession: Found session ${session.id} (${session.status})');
          return Right(session);
        },
      );
    } catch (e, stackTrace) {
      _logger.e('GetCurrentSession: Unexpected error', error: e, stackTrace: stackTrace);
      return Left(UnexpectedFailure('Failed to get current session: $e'));
    }
  }
}
