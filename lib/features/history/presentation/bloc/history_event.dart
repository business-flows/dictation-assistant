import 'package:equatable/equatable.dart';

/// Base class for all history events.
abstract class HistoryEvent extends Equatable {
  const HistoryEvent();

  @override
  List<Object?> get props => [];
}

/// Event to load all sessions for the history list.
///
/// Emitted when the history page is first opened or when
/// pull-to-refresh is triggered.
class LoadHistory extends HistoryEvent {
  const LoadHistory();
}

/// Event to search sessions by query string.
///
/// The BLoC will debounce rapid search events internally.
class SearchSessions extends HistoryEvent {
  /// The search query string.
  final String query;

  const SearchSessions(this.query);

  @override
  List<Object?> get props => [query];
}

/// Event to delete a session by ID.
///
/// After successful deletion, the BLoC will automatically refresh
/// the history list.
class DeleteSession extends HistoryEvent {
  /// The session ID to delete.
  final String id;

  const DeleteSession(this.id);

  @override
  List<Object?> get props => [id];
}

/// Event to refresh the history list.
///
/// Similar to [LoadHistory] but preserves the current search query.
class RefreshHistory extends HistoryEvent {
  const RefreshHistory();
}
