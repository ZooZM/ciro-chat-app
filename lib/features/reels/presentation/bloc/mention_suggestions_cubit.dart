import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/followed_user.dart';
import 'package:ciro_chat_app/features/reels/domain/repositories/reels_repository.dart';

enum MentionSuggestionsVisibility { hidden, loading, active }

/// v5 (FR-083): drives the `@`-mention suggestion overlay on the
/// post-details description field.
class MentionSuggestionsState extends Equatable {
  const MentionSuggestionsState({
    this.visibility = MentionSuggestionsVisibility.hidden,
    this.query = '',
    this.matches = const [],
  });

  final MentionSuggestionsVisibility visibility;
  final String query;
  final List<FollowedUser> matches;

  @override
  List<Object?> get props => [visibility, query, matches];
}

/// Fetches the uploader's followed-users list exactly once per screen visit
/// (binding rule 16) and filters it in memory on every keystroke — never a
/// per-keystroke network round-trip. An empty or failed fetch simply means
/// no overlay ever appears; typing is never blocked either way (FR-083).
@injectable
class MentionSuggestionsCubit extends Cubit<MentionSuggestionsState> {
  MentionSuggestionsCubit(this._repository) : super(const MentionSuggestionsState());

  final ReelsRepository _repository;
  List<FollowedUser> _followedUsers = const [];
  bool _loadStarted = false;

  /// Call once when the post-details screen opens. Safe to call more than
  /// once — only the first call triggers a fetch.
  Future<void> ensureLoaded() async {
    if (_loadStarted) return;
    _loadStarted = true;
    emit(const MentionSuggestionsState(visibility: MentionSuggestionsVisibility.loading));
    final result = await _repository.getFollowingUsers();
    _followedUsers = result.fold((_) => const [], (page) => page.items);
    if (isClosed) return;
    emit(const MentionSuggestionsState());
  }

  /// Call on every description text change. [token] is the active
  /// `@`-fragment (without the `@`), or `null` when no mention token is
  /// currently being typed (dismisses the panel — space, `@` deletion, blur).
  void updateToken(String? token) {
    if (token == null || _followedUsers.isEmpty) {
      _dismissIfVisible();
      return;
    }
    final lowerToken = token.toLowerCase();
    final matches = _followedUsers
        .where((u) =>
            u.username.toLowerCase().contains(lowerToken) ||
            u.name.toLowerCase().contains(lowerToken))
        .toList();
    emit(MentionSuggestionsState(
      visibility: MentionSuggestionsVisibility.active,
      query: token,
      matches: matches,
    ));
  }

  void dismiss() => _dismissIfVisible();

  void _dismissIfVisible() {
    if (state.visibility == MentionSuggestionsVisibility.hidden) return;
    emit(const MentionSuggestionsState());
  }
}
