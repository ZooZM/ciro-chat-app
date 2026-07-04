part of 'reels_feed_bloc.dart';

enum ReelsFeedStatus { initial, loadingDeepLink, loading, ready, error }

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
    this.errorMessage,
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

  /// FR-050/051: `'liked'` or `'saved'`.
  final String? listSource;
  final String? errorMessage;

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
    String? errorMessage,
    bool clearError = false,
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
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
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
        errorMessage,
      ];
}
