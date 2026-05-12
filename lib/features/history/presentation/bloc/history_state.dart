import 'package:equatable/equatable.dart';

import '../../domain/entities/session_summary_entity.dart';

/// Base class for all history states.
abstract class HistoryState extends Equatable {
  const HistoryState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any history is loaded.
class HistoryInitial extends HistoryState {
  const HistoryInitial();
}

/// State while history is being loaded.
class HistoryLoading extends HistoryState {
  const HistoryLoading();
}

/// State when history has been successfully loaded.
class HistoryLoaded extends HistoryState {
  /// List of session summaries to display.
  final List<SessionSummaryEntity> sessions;

  /// Current search query, if any.
  final String? searchQuery;

  const HistoryLoaded(this.sessions, {this.searchQuery});

  /// Creates a copy with updated fields.
  HistoryLoaded copyWith({
    List<SessionSummaryEntity>? sessions,
    String? searchQuery,
  }) {
    return HistoryLoaded(
      sessions ?? this.sessions,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  List<Object?> get props => [sessions, searchQuery];
}

/// State when no sessions exist.
class HistoryEmpty extends HistoryState {
  /// Current search query, if any.
  final String? searchQuery;

  const HistoryEmpty({this.searchQuery});

  @override
  List<Object?> get props => [searchQuery];
}

/// State when an error occurs loading history.
class HistoryError extends HistoryState {
  /// Error message to display.
  final String message;

  const HistoryError(this.message);

  @override
  List<Object?> get props => [message];
}

/// State emitted after a session has been successfully deleted.
///
/// This is a transient state — the BLoC will immediately transition
/// to [HistoryLoading] to refresh the list.
class SessionDeleted extends HistoryState {
  /// The ID of the deleted session.
  final String sessionId;

  const SessionDeleted(this.sessionId);

  @override
  List<Object?> get props => [sessionId];
}
