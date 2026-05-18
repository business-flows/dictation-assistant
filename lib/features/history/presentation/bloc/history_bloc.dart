import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/usecases/usecase.dart';
import '../../domain/usecases/delete_session.dart';
import '../../domain/usecases/get_all_sessions.dart';
import '../../domain/usecases/search_sessions.dart';
import 'history_event.dart';
import 'history_state.dart';

/// BLoC for the history feature.
///
/// Manages the state of the session history list, including:
/// - Loading all sessions
/// - Searching sessions by query
/// - Deleting sessions
/// - Refreshing the list
///
/// Usage:
/// ```dart
/// BlocProvider(
///   create: (context) => getIt<HistoryBloc>()..add(const LoadHistory()),
///   child: const HistoryListPage(),
/// )
/// ```
@singleton
class HistoryBloc extends Bloc<HistoryEvent, HistoryState> {
  final GetAllSessions _getAllSessions;
  final SearchSessions _searchSessions;
  final DeleteSession _deleteSession;

  Timer? _searchDebounce;

  HistoryBloc(
    this._getAllSessions,
    this._searchSessions,
    this._deleteSession,
  ) : super(const HistoryInitial()) {
    on<LoadHistory>(_onLoadHistory);
    on<SearchSessions>(_onSearchSessions);
    on<DeleteSession>(_onDeleteSession);
    on<RefreshHistory>(_onRefreshHistory);
  }

  /// Current search query, if any.
  String? get currentSearchQuery =>
      state is HistoryLoaded ? (state as HistoryLoaded).searchQuery : null;

  Future<void> _onLoadHistory(
    LoadHistory event,
    Emitter<HistoryState> emit,
  ) async {
    emit(const HistoryLoading());
    final result = await _getAllSessions(const NoParams());
    result.fold(
      (failure) => emit(HistoryError(failure.message)),
      (sessions) {
        if (sessions.isEmpty) {
          emit(const HistoryEmpty());
        } else {
          emit(HistoryLoaded(sessions));
        }
      },
    );
  }

  Future<void> _onSearchSessions(
    SearchSessions event,
    Emitter<HistoryState> emit,
  ) async {
    // Cancel any pending debounce timer
    _searchDebounce?.cancel();

    final trimmedQuery = event.query.trim();

    // If query is empty, load all sessions
    if (trimmedQuery.isEmpty) {
      add(const LoadHistory());
      return;
    }

    // Debounce search by 300ms
    final completer = Completer<void>();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      emit(const HistoryLoading());
      final result = await _searchSessions(
        SearchSessionsParams(query: trimmedQuery),
      );
      result.fold(
        (failure) => emit(HistoryError(failure.message)),
        (sessions) {
          if (sessions.isEmpty) {
            emit(HistoryEmpty(searchQuery: trimmedQuery));
          } else {
            emit(HistoryLoaded(sessions, searchQuery: trimmedQuery));
          }
        },
      );
      completer.complete();
    });

    await completer.future;
  }

  Future<void> _onDeleteSession(
    DeleteSession event,
    Emitter<HistoryState> emit,
  ) async {
    final previousState = state;
    emit(const HistoryLoading());

    final result = await _deleteSession(DeleteSessionParams(id: event.id));
    result.fold(
      (failure) {
        emit(HistoryError('Failed to delete session: ${failure.message}'));
      },
      (_) {
        emit(SessionDeleted(event.id));
        // Automatically refresh the list
        final query = previousState is HistoryLoaded
            ? previousState.searchQuery
            : null;
        if (query != null && query.isNotEmpty) {
          add(SearchSessions(query));
        } else {
          add(const LoadHistory());
        }
      },
    );
  }

  Future<void> _onRefreshHistory(
    RefreshHistory event,
    Emitter<HistoryState> emit,
  ) async {
    final query = state is HistoryLoaded
        ? (state as HistoryLoaded).searchQuery
        : null;

    if (query != null && query.isNotEmpty) {
      await _onSearchSessions(SearchSessions(query), emit);
    } else {
      await _onLoadHistory(const LoadHistory(), emit);
    }
  }

  @override
  Future<void> close() {
    _searchDebounce?.cancel();
    return super.close();
  }
}
