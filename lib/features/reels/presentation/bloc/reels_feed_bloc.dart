import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:ciro_chat_app/core/error/failures.dart';
import 'package:ciro_chat_app/features/reels/data/datasources/reels_prefetch_service.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/reel.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/reel_status.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/reels_page.dart';
import 'package:ciro_chat_app/features/reels/domain/repositories/reels_repository.dart';
import 'package:ciro_chat_app/features/reels/reels_constants.dart';
import 'package:ciro_chat_app/features/reels/presentation/bloc/reels_interaction_cubit.dart';
import 'package:ciro_chat_app/features/reels/presentation/services/reels_player_pool.dart';

part 'reels_feed_event.dart';
part 'reels_feed_state.dart';

/// Owns pagination, page-position, and sliding-window orchestration for the
/// Reels feed. Kept separate from [ReelsInteractionCubit] (likes/comments/
/// shares/follows) so a tap on an overlay control never triggers a rebuild
/// of anything feed-scoped — see research.md R3.
///
/// A `Bloc` (not `Cubit`) — deliberate deviation from the constitution's
/// Cubit-by-default preference, justified in plan.md Complexity Tracking:
/// pagination needs a `droppable()` event transformer to forbid
/// concurrent/duplicate fetches under fast swiping.
///
/// `@lazySingleton` (not `@injectable`) — session-scoped by design (FR-004a):
/// switching away from the Reels tab and back must resume the same video,
/// so the same bloc instance has to survive across tab switches and only
/// reset on logout or an explicit refresh.
@lazySingleton
class ReelsFeedBloc extends Bloc<ReelsFeedEvent, ReelsFeedState> {
  ReelsFeedBloc(
    this._repository,
    this._playerPool,
    this._prefetchService,
    this._interactionCubit,
  ) : super(const ReelsFeedState()) {
    _playerPool.onOpenError = (index, _) => add(ReelsItemOpenFailed(index));

    on<ReelsFeedStarted>(_onStarted);
    on<ReelsPageChanged>(_onPageChanged);
    on<ReelsFeedPaused>(_onPaused);
    on<ReelsFeedResumed>(_onResumed);
    on<ReelsRefreshRequested>(_onRefresh);
    on<ReelsFeedScopeChanged>(_onScopeChanged, transformer: droppable());
    on<ReelsNextPageRequested>(_onNextPage, transformer: droppable());
    on<ReelsItemRetryRequested>(_onItemRetry);
    on<ReelsItemOpenFailed>(_onItemOpenFailed);
    on<ReelsFeedReset>(_onReset);
  }

  final ReelsRepository _repository;
  final ReelsPlayerPool _playerPool;
  final ReelsPrefetchService _prefetchService;
  final ReelsInteractionCubit _interactionCubit;

  /// Called from the global logout sequence (constitution V-A). Convenience
  /// wrapper matching the `getIt<X>().reset()` call-site pattern used by the
  /// other cubits there — `Bloc.emit` isn't public, so this dispatches an
  /// event internally rather than mutating state directly.
  void resetForLogout() => add(const ReelsFeedReset());

  Future<void> _onStarted(ReelsFeedStarted event, Emitter<ReelsFeedState> emit) async {
    // The bloc is a session-scoped singleton shared by the main tab, any
    // creator-scoped feed, and any deep-linked reel screen — persist/clear
    // scope explicitly on every start so returning to the main tab after
    // visiting a scoped view doesn't keep showing the scoped content.
    emit(
      state.copyWith(
        status: event.initialReelId != null ? ReelsFeedStatus.loadingDeepLink : ReelsFeedStatus.loading,
        clearError: true,
        failedItemIds: const {},
        paginationFailed: false,
        initialReelId: event.initialReelId,
        clearInitialReelId: event.initialReelId == null,
        deepLinkFailed: false,
        creatorId: event.creatorId,
        clearCreatorId: event.creatorId == null,
        hashtag: event.hashtag,
        clearHashtag: event.hashtag == null,
        listSource: event.listSource,
        clearListSource: event.listSource == null,
        listSourceUserId: event.listSourceUserId,
        clearListSourceUserId: event.listSourceUserId == null,
        // v4: a genuine fresh start (first-ever mount of this scope-shape,
        // or an explicit refresh via _onRefresh) invalidates any cached tab
        // snapshot — resume-within-session only applies across push/pop
        // navigation, not across an explicit reset. The plain main-feed
        // screen's own feedScope is preserved (defaults to forYou on a
        // truly fresh bloc; _onRefresh re-passes the currently active one).
        scopeSnapshots: const {},
      ),
    );
    _playerPool.disposeAll();

    Reel? seedReel;
    if (event.initialReelId != null) {
      final reelResult = await _repository.fetchReel(event.initialReelId!);
      reelResult.fold(
        (failure) => emit(state.copyWith(deepLinkFailed: true)),
        (reel) => seedReel = reel,
      );
      emit(state.copyWith(status: ReelsFeedStatus.loading));
    }

    final result = await _fetchScopedPage(
      creatorId: event.creatorId,
      hashtag: event.hashtag,
      listSource: event.listSource,
      listSourceUserId: event.listSourceUserId,
      feedScope: state.feedScope,
    );
    result.fold(
      (failure) => emit(state.copyWith(status: ReelsFeedStatus.error, errorMessage: failure.message)),
      (page) {
        // FR-040: the linked reel leads the feed; dedupe if the normal page
        // also contains it (common when it's simply a recent upload).
        final items = seedReel == null
            ? page.items
            : [seedReel!, ...page.items.where((r) => r.id != seedReel!.id)];
        emit(
          state.copyWith(
            status: ReelsFeedStatus.ready,
            reels: items,
            currentIndex: 0,
            nextCursor: page.nextCursor,
            clearNextCursor: page.nextCursor == null,
          ),
        );
        if (items.isNotEmpty) {
          _syncWindowAndPrefetch(0, items);
          // v3 (FR-064): engagement is 404 on a non-published reel — only
          // the owner ever reaches one here (own-profile deep dive), so
          // skip the fire-and-forget call rather than let it fail silently.
          if (items[0].status == ReelStatus.published) {
            _interactionCubit.recordView(items[0].id);
          }
        }
        _interactionCubit.seedReels(items);
      },
    );
  }

  void _onPageChanged(ReelsPageChanged event, Emitter<ReelsFeedState> emit) {
    if (event.index < 0 || event.index >= state.reels.length) return;
    emit(state.copyWith(currentIndex: event.index));
    _syncWindowAndPrefetch(event.index, state.reels);
    final current = state.reels[event.index];
    if (current.status == ReelStatus.published) {
      _interactionCubit.recordView(current.id);
    }

    // FR-007: request the next page once fewer than prefetchPageThreshold
    // unseen reels remain ahead of the current index.
    final remaining = state.reels.length - 1 - event.index;
    if (remaining < ReelsConstants.prefetchPageThreshold && !state.isLoadingMore) {
      add(const ReelsNextPageRequested());
    }
  }

  /// Syncs the live-player window and fires the best-effort N+2 network
  /// prefetch (FR-010) — both are fire-and-forget, never awaited here, so a
  /// swipe never blocks on video I/O (FR-011).
  void _syncWindowAndPrefetch(int index, List<Reel> reels) {
    _playerPool.syncWindow(index, reels);
    final prefetchIndex = index + 2;
    if (prefetchIndex < reels.length) {
      _prefetchService.prefetch(reels[prefetchIndex].videoUrl);
    }
  }

  void _onPaused(ReelsFeedPaused event, Emitter<ReelsFeedState> emit) {
    _playerPool.pauseAll();
  }

  void _onResumed(ReelsFeedResumed event, Emitter<ReelsFeedState> emit) {
    if (state.reels.isEmpty) return;
    _playerPool.syncWindow(state.currentIndex, state.reels);
  }

  Future<void> _onRefresh(ReelsRefreshRequested event, Emitter<ReelsFeedState> emit) async {
    // _onStarted disposes the pool itself; deliberately drop initialReelId
    // here — a refresh re-fetches the live feed, not the original deep link.
    await _onStarted(
      ReelsFeedStarted(
        creatorId: state.creatorId,
        hashtag: state.hashtag,
        listSource: state.listSource,
        listSourceUserId: state.listSourceUserId,
      ),
      emit,
    );
  }

  /// Routes to the feed/hashtag endpoint, the caller's own Liked/Saved list,
  /// or (v4, FR-074/FR-075) the Following tab, depending on which scope is
  /// active (mutually exclusive). [feedScope] only matters for the plain
  /// main-feed screen — any of [creatorId]/[hashtag]/[listSource] wins over it.
  Future<Either<Failure, ReelsPage>> _fetchScopedPage({
    String? cursor,
    String? creatorId,
    String? hashtag,
    String? listSource,
    String? listSourceUserId,
    ReelFeedScope feedScope = ReelFeedScope.forYou,
  }) {
    if (listSource == 'liked') return _repository.fetchLiked(cursor: cursor);
    if (listSource == 'saved') return _repository.fetchSaved(cursor: cursor);
    if (listSource == 'reposted') {
      return _repository.fetchReposted(userId: listSourceUserId, cursor: cursor);
    }
    if (creatorId == null && hashtag == null && feedScope == ReelFeedScope.following) {
      return _repository.fetchFollowing(cursor: cursor);
    }
    return _repository.fetchFeed(cursor: cursor, creatorId: creatorId, hashtag: hashtag);
  }

  /// v4 (FR-074/FR-004a): switches the active tab. A snapshot exists for the
  /// target scope → instant restore (no refetch, resumes at its exact prior
  /// position). Otherwise fetches page 1 for it (first visit this session).
  /// Ignored entirely for scoped views (creator/hashtag/liked/saved/deep
  /// link) — those have nothing to do with the Following/For You toggle.
  Future<void> _onScopeChanged(
    ReelsFeedScopeChanged event,
    Emitter<ReelsFeedState> emit,
  ) async {
    if (event.scope == state.feedScope) return;
    if (state.creatorId != null || state.hashtag != null || state.listSource != null) {
      return;
    }

    final snapshots = Map<ReelFeedScope, ReelsScopeSnapshot>.from(state.scopeSnapshots)
      ..[state.feedScope] = ReelsScopeSnapshot(
        reels: state.reels,
        currentIndex: state.currentIndex,
        nextCursor: state.nextCursor,
      );

    // The player pool is keyed by INDEX, not reel id (research.md R20) — a
    // stale player would otherwise keep playing the OUTGOING scope's video
    // at whatever index the incoming scope reuses. Always tear down first so
    // the outgoing tab's audio stops immediately (FR-004/FR-074).
    _playerPool.disposeAll();

    final cached = snapshots[event.scope];
    if (cached != null) {
      emit(
        state.copyWith(
          feedScope: event.scope,
          reels: cached.reels,
          currentIndex: cached.currentIndex,
          nextCursor: cached.nextCursor,
          clearNextCursor: cached.nextCursor == null,
          scopeSnapshots: snapshots,
          status: ReelsFeedStatus.ready,
        ),
      );
      if (cached.reels.isNotEmpty) {
        _syncWindowAndPrefetch(cached.currentIndex, cached.reels);
        final resumed = cached.reels[cached.currentIndex];
        if (resumed.status == ReelStatus.published) {
          _interactionCubit.recordView(resumed.id);
        }
      }
      return;
    }

    // First visit to this scope this session — fetch page 1.
    emit(
      state.copyWith(
        feedScope: event.scope,
        status: ReelsFeedStatus.loading,
        reels: const [],
        currentIndex: 0,
        scopeSnapshots: snapshots,
        clearNextCursor: true,
      ),
    );
    final result = await _fetchScopedPage(feedScope: event.scope);
    result.fold(
      (failure) => emit(state.copyWith(status: ReelsFeedStatus.error, errorMessage: failure.message)),
      (page) {
        emit(
          state.copyWith(
            status: ReelsFeedStatus.ready,
            reels: page.items,
            currentIndex: 0,
            nextCursor: page.nextCursor,
            clearNextCursor: page.nextCursor == null,
          ),
        );
        if (page.items.isNotEmpty) {
          _syncWindowAndPrefetch(0, page.items);
          if (page.items[0].status == ReelStatus.published) {
            _interactionCubit.recordView(page.items[0].id);
          }
        }
        _interactionCubit.seedReels(page.items);
      },
    );
  }

  Future<void> _onNextPage(ReelsNextPageRequested event, Emitter<ReelsFeedState> emit) async {
    if (state.isLoadingMore || state.nextCursor == null) return;
    emit(state.copyWith(isLoadingMore: true, paginationFailed: false));
    final result = await _fetchScopedPage(
      cursor: state.nextCursor,
      creatorId: state.creatorId,
      hashtag: state.hashtag,
      listSource: state.listSource,
      listSourceUserId: state.listSourceUserId,
      feedScope: state.feedScope,
    );
    result.fold(
      (failure) => emit(state.copyWith(isLoadingMore: false, paginationFailed: true)),
      (page) {
        emit(
          state.copyWith(
            reels: [...state.reels, ...page.items],
            nextCursor: page.nextCursor,
            clearNextCursor: page.nextCursor == null,
            isLoadingMore: false,
            paginationFailed: false,
          ),
        );
        _interactionCubit.seedReels(page.items);
      },
    );
  }

  void _onItemOpenFailed(ReelsItemOpenFailed event, Emitter<ReelsFeedState> emit) {
    if (event.index < 0 || event.index >= state.reels.length) return;
    final id = state.reels[event.index].id;
    emit(state.copyWith(failedItemIds: {...state.failedItemIds, id}));
  }

  void _onItemRetry(ReelsItemRetryRequested event, Emitter<ReelsFeedState> emit) {
    if (event.index < 0 || event.index >= state.reels.length) return;
    final id = state.reels[event.index].id;
    emit(state.copyWith(failedItemIds: {...state.failedItemIds}..remove(id)));
    _playerPool.evict(event.index);
    _playerPool.syncWindow(state.currentIndex, state.reels);
  }

  void _onReset(ReelsFeedReset event, Emitter<ReelsFeedState> emit) {
    _playerPool.disposeAll();
    emit(const ReelsFeedState());
  }

  @override
  Future<void> close() {
    _playerPool.disposeAll();
    return super.close();
  }
}
