import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/reel.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/search_user.dart';
import 'package:ciro_chat_app/features/reels/domain/repositories/reels_repository.dart';

enum SearchStatus { idle, loading, ready, error }

class SearchState extends Equatable {
  const SearchState({
    this.status = SearchStatus.idle,
    this.query = '',
    this.videos = const [],
    this.users = const [],
  });

  final SearchStatus status;
  final String query;
  final List<Reel> videos;
  final List<SearchUser> users;

  SearchState copyWith({
    SearchStatus? status,
    String? query,
    List<Reel>? videos,
    List<SearchUser>? users,
  }) {
    return SearchState(
      status: status ?? this.status,
      query: query ?? this.query,
      videos: videos ?? this.videos,
      users: users ?? this.users,
    );
  }

  @override
  List<Object?> get props => [status, query, videos, users];
}

/// FR-057: searches reels by hashtag substring and users by name/username
/// substring in parallel. Debounced 350 ms; stale responses (superseded by a
/// newer query before they return) are dropped via a query token.
@injectable
class SearchCubit extends Cubit<SearchState> {
  SearchCubit(this._repository) : super(const SearchState());

  final ReelsRepository _repository;
  Timer? _debounce;
  int _queryToken = 0;

  void search(String rawQuery) {
    _debounce?.cancel();
    final query = rawQuery.trim();
    if (query.isEmpty) {
      emit(const SearchState());
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _runSearch(query));
  }

  Future<void> _runSearch(String query) async {
    final token = ++_queryToken;
    emit(state.copyWith(status: SearchStatus.loading, query: query));

    final videosFuture = _repository.searchReels(query);
    final usersFuture = _repository.searchUsers(query);
    final videosResult = await videosFuture;
    final usersResult = await usersFuture;
    if (token != _queryToken || isClosed) return;

    final videos = videosResult.fold((_) => const <Reel>[], (page) => page.items);
    final users = usersResult.fold((_) => const <SearchUser>[], (r) => r.items);
    final hadError = videosResult.isLeft() && usersResult.isLeft();

    emit(
      state.copyWith(
        status: hadError ? SearchStatus.error : SearchStatus.ready,
        videos: videos,
        users: users,
      ),
    );
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
