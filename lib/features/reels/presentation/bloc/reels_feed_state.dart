part of 'reels_feed_bloc.dart';

enum ReelsFeedStatus { initial, loadingDeepLink, loading, ready, error }

/// v4 (FR-074): the two top-level Reels tabs. Only meaningful for the plain
/// main-feed screen (no creatorId/hashtag/listSource/initialReelId scoping)
/// — [ReelsFeedBloc.feedScope] is ignored by every other scoped view.
enum ReelFeedScope { forYou, following }

/// v4 (FR-074/FR-004a): a snapshot of the OTHER tab's list/position/cursor,
/// kept so switching back to it is instant (no refetch, no lost position).
class ReelsScopeSnapshot extends Equatable {
  const ReelsScopeSnapshot({
    required this.reels,
    required this.currentIndex,
    required this.nextCursor,
  });

  final List<Reel> reels;
  final int currentIndex;
  final String? nextCursor;

  @override
  List<Object?> get props => [reels, currentIndex, nextCursor];
}

class ReelsFeedState extends Equatable {
  const ReelsFeedState({
    this.status = ReelsFeedStatus.initial,
    this.reels = const [],
    this.currentIndex = 0,
    this.nextCursor,
    this.isLoadingMore = false,
    this.failedItemIds = const {},
    this.paginationFailed = false,
    this.initialReelId,
    this.deepLinkFailed = false,
    this.creatorId,
    this.hashtag,
    this.listSource,
    this.listSourceUserId,
    this.errorMessage,
    this.feedScope = ReelFeedScope.forYou,
    this.scopeSnapshots = const {},
  });

  final ReelsFeedStatus status;
  final List<Reel> reels;
  final int currentIndex;
  final String? nextCursor;
  final bool isLoadingMore;
  final Set<String> failedItemIds;
  final bool paginationFailed;
  final String? initialReelId;
  final bool deepLinkFailed;
  final String? creatorId;

  /// FR-047a: hashtag-scoped feed.
  final String? hashtag;

  /// FR-050/051: `'liked'`/`'saved'`, or v6 `'reposted'`.
  final String? listSource;

  /// v6: whose reposts when [listSource] is `'reposted'` (null → caller).
  final String? listSourceUserId;
  final String? errorMessage;

  /// v4 (FR-074): which tab is currently active — only meaningful when
  /// [creatorId]/[hashtag]/[listSource]/[initialReelId] are all null (the
  /// plain main-feed screen).
  final ReelFeedScope feedScope;

  /// v4 (FR-074/FR-004a): the OTHER (inactive) scope's saved position, so
  /// switching back to it is instant. Never holds an entry for [feedScope]
  /// itself — that scope's live data is always [reels]/[currentIndex]/
  /// [nextCursor] directly.
  final Map<ReelFeedScope, ReelsScopeSnapshot> scopeSnapshots;

  ReelsFeedState copyWith({
    ReelsFeedStatus? status,
    List<Reel>? reels,
    int? currentIndex,
    String? nextCursor,
    bool clearNextCursor = false,
    bool? isLoadingMore,
    Set<String>? failedItemIds,
    bool? paginationFailed,
    String? initialReelId,
    bool clearInitialReelId = false,
    bool? deepLinkFailed,
    String? creatorId,
    bool clearCreatorId = false,
    String? hashtag,
    bool clearHashtag = false,
    String? listSource,
    bool clearListSource = false,
    String? listSourceUserId,
    bool clearListSourceUserId = false,
    String? errorMessage,
    bool clearError = false,
    ReelFeedScope? feedScope,
    Map<ReelFeedScope, ReelsScopeSnapshot>? scopeSnapshots,
  }) {
    return ReelsFeedState(
      status: status ?? this.status,
      reels: reels ?? this.reels,
      currentIndex: currentIndex ?? this.currentIndex,
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      failedItemIds: failedItemIds ?? this.failedItemIds,
      paginationFailed: paginationFailed ?? this.paginationFailed,
      initialReelId: clearInitialReelId ? null : (initialReelId ?? this.initialReelId),
      deepLinkFailed: deepLinkFailed ?? this.deepLinkFailed,
      creatorId: clearCreatorId ? null : (creatorId ?? this.creatorId),
      hashtag: clearHashtag ? null : (hashtag ?? this.hashtag),
      listSource: clearListSource ? null : (listSource ?? this.listSource),
      listSourceUserId:
          clearListSourceUserId ? null : (listSourceUserId ?? this.listSourceUserId),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      feedScope: feedScope ?? this.feedScope,
      scopeSnapshots: scopeSnapshots ?? this.scopeSnapshots,
    );
  }

  @override
  List<Object?> get props => [
        status,
        reels,
        currentIndex,
        nextCursor,
        isLoadingMore,
        failedItemIds,
        paginationFailed,
        initialReelId,
        deepLinkFailed,
        creatorId,
        hashtag,
        listSource,
        listSourceUserId,
        errorMessage,
        feedScope,
        scopeSnapshots,
      ];
}
