import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ciro_chat_app/core/di/injection.dart';
import 'package:ciro_chat_app/core/routing/app_router.dart' show reelsRouteObserver;
import 'package:ciro_chat_app/features/reels/presentation/bloc/reels_feed_bloc.dart';
import 'package:ciro_chat_app/features/reels/presentation/services/reels_player_pool.dart';
import 'package:ciro_chat_app/features/reels/presentation/widgets/reel_page.dart';
import 'package:ciro_chat_app/features/reels/presentation/widgets/reel_skeleton.dart';
import 'package:ciro_chat_app/features/reels/presentation/widgets/reels_my_profile_header.dart';

/// Full-screen vertical reel feed (US1/US2). Embedded as the Reels tab body
/// and also reachable via the `/reels/:id` and `/reels/creator/:id`
/// deep-link routes.
class ReelsFeedScreen extends StatefulWidget {
  const ReelsFeedScreen({
    super.key,
    this.initialReelId,
    this.creatorId,
    this.hashtag,
    this.listSource,
  });

  final String? initialReelId;
  final String? creatorId;

  /// FR-047a: hashtag-scoped feed.
  final String? hashtag;

  /// FR-050/051: `'liked'` or `'saved'` — the caller's own scoped lists.
  final String? listSource;

  @override
  State<ReelsFeedScreen> createState() => _ReelsFeedScreenState();
}

class _ReelsFeedScreenState extends State<ReelsFeedScreen>
    with WidgetsBindingObserver, RouteAware {
  final ReelsFeedBloc _bloc = getIt<ReelsFeedBloc>();
  late final PageController _pageController;
  bool _isSubscribedToRouteObserver = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController(initialPage: _syncScope());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribed once per widget instance — this screen may be the
    // persistent main-tab body sitting underneath pushed routes (Creator
    // Profile, a scoped feed), which never rebuild/re-run initState when
    // those routes are popped back off. RouteAware.didPopNext is what
    // signals "you're visible again", independent of any rebuild.
    if (_isSubscribedToRouteObserver) return;
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      reelsRouteObserver.subscribe(this, route);
      _isSubscribedToRouteObserver = true;
    }
  }

  /// Compares this screen's requested scope against the shared
  /// [ReelsFeedBloc] singleton's current scope and resumes in place only if
  /// they match — otherwise (first-ever open, switching between scopes, or
  /// the bloc's scope having drifted while this screen sat unmounted-from-
  /// view under a pushed route) triggers a fresh load. Returns the page
  /// index the `PageView` should start/resume at.
  int _syncScope() {
    final sameScope =
        _bloc.state.creatorId == widget.creatorId &&
        _bloc.state.hashtag == widget.hashtag &&
        _bloc.state.listSource == widget.listSource &&
        (widget.initialReelId == null ||
            _bloc.state.initialReelId == widget.initialReelId);
    final needsFreshLoad =
        _bloc.state.status == ReelsFeedStatus.initial || !sameScope;

    if (needsFreshLoad) {
      _bloc.add(
        ReelsFeedStarted(
          initialReelId: widget.initialReelId,
          creatorId: widget.creatorId,
          hashtag: widget.hashtag,
          listSource: widget.listSource,
        ),
      );
      return 0;
    }
    _bloc.add(const ReelsFeedResumed());
    return _bloc.state.currentIndex;
  }

  /// Fires when a route pushed on top of this screen (e.g. a creator-scoped
  /// feed or another profile) is popped, making this screen visible again.
  @override
  void didPopNext() {
    final targetIndex = _syncScope();
    if (_pageController.hasClients &&
        _pageController.page?.round() != targetIndex) {
      _pageController.jumpToPage(targetIndex);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _bloc.add(const ReelsFeedPaused());
    } else if (state == AppLifecycleState.resumed) {
      _bloc.add(const ReelsFeedResumed());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    reelsRouteObserver.unsubscribe(this);
    // FR-004: leaving the tab must stop playback immediately. The bloc is a
    // session-scoped singleton, so this only pauses — state (and resume
    // position, FR-004a) survives until logout or an explicit refresh.
    _bloc.add(const ReelsFeedPaused());
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: BlocListener<ReelsFeedBloc, ReelsFeedState>(
        bloc: _bloc,
        listenWhen: (previous, current) =>
            !previous.deepLinkFailed && current.deepLinkFailed,
        // FR-043: an unknown/deleted linked reel shows a friendly notice and
        // falls back to the regular feed (already loading behind it).
        listener: (context, state) => ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('reels.deep_link_error'.tr()))),
        child: Stack(
          children: [
            BlocBuilder<ReelsFeedBloc, ReelsFeedState>(
              bloc: _bloc,
              buildWhen: (previous, current) =>
                  previous.status != current.status ||
                  previous.reels.length != current.reels.length ||
                  previous.failedItemIds != current.failedItemIds,
              builder: (context, state) {
                switch (state.status) {
                  case ReelsFeedStatus.initial:
                  case ReelsFeedStatus.loading:
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  case ReelsFeedStatus.loadingDeepLink:
                    // FR-041: a skeleton, never a blank screen, while the
                    // linked reel is being fetched.
                    return const ReelSkeleton();
                  case ReelsFeedStatus.error:
                    return _ReelsErrorState(
                      message: state.errorMessage,
                      onRetry: () => _bloc.add(const ReelsRefreshRequested()),
                    );
                  case ReelsFeedStatus.ready:
                    if (state.reels.isEmpty) {
                      return _ReelsEmptyState(
                        onRetry: () => _bloc.add(const ReelsRefreshRequested()),
                      );
                    }
                    return PageView.builder(
                      controller: _pageController,
                      scrollDirection: Axis.vertical,
                      itemCount: state.reels.length,
                      onPageChanged: (index) =>
                          _bloc.add(ReelsPageChanged(index)),
                      itemBuilder: (context, index) {
                        final reel = state.reels[index];
                        return ReelPage(
                          reel: reel,
                          controller: getIt<ReelsPlayerPool>().controllerFor(
                            index,
                          ),
                          isFailed: state.failedItemIds.contains(reel.id),
                          onRetry: () =>
                              _bloc.add(ReelsItemRetryRequested(index)),
                          onCreatorTap: () =>
                              context.push('/reels/profile/${reel.creator.id}'),
                        );
                      },
                    );
                }
              },
            ),
            // Non-blocking pagination-retry banner (FR-036) — an isolated
            // BlocBuilder so a pagination hiccup never rebuilds the PageView.
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: BlocBuilder<ReelsFeedBloc, ReelsFeedState>(
                bloc: _bloc,
                buildWhen: (previous, current) =>
                    previous.paginationFailed != current.paginationFailed,
                builder: (context, state) {
                  if (!state.paginationFailed) return const SizedBox.shrink();
                  return Center(
                    child: Material(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _bloc.add(const ReelsNextPageRequested()),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.refresh,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'reels.retry'.tr(),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // Top overlay — mutually exclusive, matching how this screen was
            // reached:
            //  - Pushed (chat card tap, creator profile grid, warm-app deep
            //    link): a back/close affordance, since there's nothing else
            //    to get out with (FR-004).
            //  - Embedded as the main tab body: the logged-in user's own
            //    avatar (→ their Creator Profile) + a search icon, matching
            //    the TikTok/Instagram-style Reels home header. The bottom
            //    nav bar is the way out here, so no back button.
            if (Navigator.of(context).canPop())
              Positioned(
                top: 8,
                left: 8,
                child: SafeArea(
                  child: Material(
                    color: Colors.black45,
                    shape: const CircleBorder(),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              )
            else
              const Positioned(
                top: 8,
                left: 12,
                right: 12,
                child: SafeArea(child: ReelsMyProfileHeader()),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReelsEmptyState extends StatelessWidget {
  const _ReelsEmptyState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.video_camera_back_outlined,
            color: Colors.white54,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            'reels.empty_title'.tr(),
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            'reels.empty_subtitle'.tr(),
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: Text('reels.retry'.tr())),
        ],
      ),
    );
  }
}

class _ReelsErrorState extends StatelessWidget {
  const _ReelsErrorState({required this.onRetry, this.message});

  final VoidCallback onRetry;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.white54, size: 48),
          const SizedBox(height: 12),
          Text(
            'reels.error_title'.tr(),
            style: const TextStyle(color: Colors.white),
          ),
          if (message != null && message!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              message!,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: Text('reels.retry'.tr())),
        ],
      ),
    );
  }
}
