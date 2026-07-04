import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/reel.dart';
import 'package:ciro_chat_app/features/reels/domain/repositories/reels_repository.dart';

class LikeEntry extends Equatable {
  const LikeEntry({required this.liked, required this.count});

  final bool liked;
  final int count;

  LikeEntry copyWith({bool? liked, int? count}) =>
      LikeEntry(liked: liked ?? this.liked, count: count ?? this.count);

  @override
  List<Object?> get props => [liked, count];
}

class FollowEntry extends Equatable {
  const FollowEntry({required this.following, required this.followersCount});

  final bool following;
  final int followersCount;

  FollowEntry copyWith({bool? following, int? followersCount}) => FollowEntry(
        following: following ?? this.following,
        followersCount: followersCount ?? this.followersCount,
      );

  @override
  List<Object?> get props => [following, followersCount];
}

class ReelsInteractionState extends Equatable {
  const ReelsInteractionState({
    this.likes = const {},
    this.commentCounts = const {},
    this.shareCounts = const {},
    this.follows = const {},
    this.saves = const {},
    this.lastActionFailed = false,
  });

  /// Keyed by reel id.
  final Map<String, LikeEntry> likes;
  final Map<String, int> commentCounts;
  final Map<String, int> shareCounts;

  /// Keyed by **creator** id — shared between the overlay and the Creator
  /// Profile screen so both stay consistent (FR-030).
  final Map<String, FollowEntry> follows;

  /// FR-049: private toggle, no public counter — keyed by reel id.
  final Map<String, bool> saves;

  /// One-shot flag surfaced as a transient notice on a reverted optimistic
  /// action (FR-037); the UI clears it after showing the notice.
  final bool lastActionFailed;

  ReelsInteractionState copyWith({
    Map<String, LikeEntry>? likes,
    Map<String, int>? commentCounts,
    Map<String, int>? shareCounts,
    Map<String, FollowEntry>? follows,
    Map<String, bool>? saves,
    bool? lastActionFailed,
  }) {
    return ReelsInteractionState(
      likes: likes ?? this.likes,
      commentCounts: commentCounts ?? this.commentCounts,
      shareCounts: shareCounts ?? this.shareCounts,
      follows: follows ?? this.follows,
      saves: saves ?? this.saves,
      lastActionFailed: lastActionFailed ?? false,
    );
  }

  @override
  List<Object?> get props =>
      [likes, commentCounts, shareCounts, follows, saves, lastActionFailed];
}

/// Owns Love/Comment-count/Share-count/Follow state, id-keyed so every
/// `BlocSelector` in the overlay watches exactly one entry — tapping Love on
/// one reel never rebuilds anything else (FR-014, research.md R3).
///
/// Deliberately a separate singleton from [ReelsFeedBloc]: interaction taps
/// never touch feed state, so they can never trigger a `PageView` rebuild.
/// The one-way seeding call (`seedReels`, feed → interaction) is safe
/// because it never flows back the other way.
@lazySingleton
class ReelsInteractionCubit extends Cubit<ReelsInteractionState> {
  ReelsInteractionCubit(this._repository) : super(const ReelsInteractionState());

  final ReelsRepository _repository;

  /// FR-048: fire-and-forget view recording is deduped per reel per session
  /// client-side too, so a re-visible reel (scrolled back to) never re-fires
  /// the request — the server also dedupes, this just saves the round trip.
  final Set<String> _viewedThisSession = {};

  /// Full teardown for the global logout sequence (constitution V-A) —
  /// clears all id-keyed state so the next login starts with a blank slate.
  void reset() {
    _viewedThisSession.clear();
    emit(const ReelsInteractionState());
  }

  /// Populates likes/comments/shares/follow entries from freshly-fetched
  /// reels — called by [ReelsFeedBloc] on initial load and pagination so the
  /// overlay never renders with missing data.
  void seedReels(List<Reel> reels) {
    if (reels.isEmpty) return;
    final likes = Map<String, LikeEntry>.from(state.likes);
    final commentCounts = Map<String, int>.from(state.commentCounts);
    final shareCounts = Map<String, int>.from(state.shareCounts);
    final follows = Map<String, FollowEntry>.from(state.follows);
    final saves = Map<String, bool>.from(state.saves);
    for (final reel in reels) {
      likes.putIfAbsent(reel.id, () => LikeEntry(liked: reel.viewerLiked, count: reel.likesCount));
      commentCounts.putIfAbsent(reel.id, () => reel.commentsCount);
      shareCounts.putIfAbsent(reel.id, () => reel.sharesCount);
      follows.putIfAbsent(
        reel.creator.id,
        () => FollowEntry(following: reel.creator.viewerFollowing, followersCount: 0),
      );
      saves.putIfAbsent(reel.id, () => reel.viewerSaved);
    }
    emit(
      state.copyWith(
        likes: likes,
        commentCounts: commentCounts,
        shareCounts: shareCounts,
        follows: follows,
        saves: saves,
      ),
    );
  }

  /// Seeds a follow entry from the Creator Profile screen (FR-030) — uses
  /// `putIfAbsent` so an in-flight or already-applied optimistic toggle from
  /// the feed overlay is never clobbered by a profile fetch snapshot.
  void seedFollow(String creatorId, {required bool following, required int followersCount}) {
    // `followersCount` here is always authoritative (a real Creator Profile
    // fetch) and MUST overwrite any placeholder planted by seedReels, which
    // has no real count to give (the feed DTO doesn't carry it) and seeds a
    // dummy 0 instead. Only `following` needs the "don't clobber" guard —
    // that one can legitimately hold a fresher in-flight optimistic value
    // from a tap on the overlay moments before this profile finished loading.
    final existing = state.follows[creatorId];
    final follows = Map<String, FollowEntry>.from(state.follows)
      ..[creatorId] = FollowEntry(
        following: existing?.following ?? following,
        followersCount: followersCount,
      );
    emit(state.copyWith(follows: follows));
  }

  Future<void> toggleLike(String reelId) async {
    final current = state.likes[reelId] ?? const LikeEntry(liked: false, count: 0);
    final optimistic = current.copyWith(
      liked: !current.liked,
      count: current.count + (current.liked ? -1 : 1),
    );
    _setLike(reelId, optimistic);

    final result = await _repository.toggleLike(reelId);
    result.fold(
      (failure) {
        _setLike(reelId, current);
        emit(state.copyWith(lastActionFailed: true));
      },
      (success) => _setLike(reelId, LikeEntry(liked: success.liked, count: success.likesCount)),
    );
  }

  void _setLike(String reelId, LikeEntry entry) {
    final likes = Map<String, LikeEntry>.from(state.likes)..[reelId] = entry;
    emit(state.copyWith(likes: likes));
  }

  void setCommentCount(String reelId, int count) {
    final commentCounts = Map<String, int>.from(state.commentCounts)..[reelId] = count;
    emit(state.copyWith(commentCounts: commentCounts));
  }

  /// Fired only on an in-app chat send or Copy Link (FR-021a) — never on
  /// merely opening the share sheet.
  Future<void> recordShare(String reelId) async {
    final result = await _repository.recordShare(reelId);
    result.fold((_) {}, (count) {
      final shareCounts = Map<String, int>.from(state.shareCounts)..[reelId] = count;
      emit(state.copyWith(shareCounts: shareCounts));
    });
  }

  Future<void> toggleFollow(String creatorId) async {
    final current = state.follows[creatorId] ?? const FollowEntry(following: false, followersCount: 0);
    final optimistic = current.copyWith(
      following: !current.following,
      followersCount: current.followersCount + (current.following ? -1 : 1),
    );
    _setFollow(creatorId, optimistic);

    final result = await _repository.toggleFollow(creatorId);
    result.fold(
      (failure) {
        _setFollow(creatorId, current);
        emit(state.copyWith(lastActionFailed: true));
      },
      (success) => _setFollow(
        creatorId,
        FollowEntry(following: success.following, followersCount: success.followersCount),
      ),
    );
  }

  void _setFollow(String creatorId, FollowEntry entry) {
    final follows = Map<String, FollowEntry>.from(state.follows)..[creatorId] = entry;
    emit(state.copyWith(follows: follows));
  }

  /// FR-049: optimistic toggle, reverted with a non-intrusive notice on failure.
  Future<void> toggleSave(String reelId) async {
    final current = state.saves[reelId] ?? false;
    _setSave(reelId, !current);

    final result = await _repository.toggleSave(reelId);
    result.fold(
      (failure) {
        _setSave(reelId, current);
        emit(state.copyWith(lastActionFailed: true));
      },
      (saved) => _setSave(reelId, saved),
    );
  }

  void _setSave(String reelId, bool saved) {
    final saves = Map<String, bool>.from(state.saves)..[reelId] = saved;
    emit(state.copyWith(saves: saves));
  }

  /// FR-048: fires once per reel per session, on playback start. Silent
  /// failure (constitution VII) — a lost view must never disrupt playback.
  void recordView(String reelId) {
    if (_viewedThisSession.contains(reelId)) return;
    _viewedThisSession.add(reelId);
    _repository.recordView(reelId).ignore();
  }
}
