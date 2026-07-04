part of 'reels_feed_bloc.dart';

sealed class ReelsFeedEvent extends Equatable {
  const ReelsFeedEvent();

  @override
  List<Object?> get props => [];
}

/// Initial load — optionally seeded by a deep link (US6, wired in a later
/// phase; `initialReelId` is accepted now so the constructor shape is stable).
class ReelsFeedStarted extends ReelsFeedEvent {
  const ReelsFeedStarted({this.initialReelId, this.creatorId, this.hashtag, this.listSource});

  final String? initialReelId;
  final String? creatorId;

  /// FR-047a: hashtag-scoped feed (finite, like [creatorId]).
  final String? hashtag;

  /// FR-050/051: `'liked'` or `'saved'` — the caller's own scoped lists.
  final String? listSource;

  @override
  List<Object?> get props => [initialReelId, creatorId, hashtag, listSource];
}

/// Fired by the PageView on every settled swipe (FR-005).
class ReelsPageChanged extends ReelsFeedEvent {
  const ReelsPageChanged(this.index);

  final int index;

  @override
  List<Object?> get props => [index];
}

/// Tab switch away / app background (FR-004) — pauses playback but keeps state.
class ReelsFeedPaused extends ReelsFeedEvent {
  const ReelsFeedPaused();
}

/// Tab switch back (FR-004a) — resumes the same video, no refetch.
class ReelsFeedResumed extends ReelsFeedEvent {
  const ReelsFeedResumed();
}

/// Explicit pull-to-refresh or retry action — the only other way to reset
/// the feed besides an app restart (FR-004a).
class ReelsRefreshRequested extends ReelsFeedEvent {
  const ReelsRefreshRequested();
}

/// Fired when the visible index nears the end of the loaded list (FR-007).
/// Uses a `droppable()` transformer so fast swiping never queues duplicate
/// in-flight fetches — see plan.md Complexity Tracking.
class ReelsNextPageRequested extends ReelsFeedEvent {
  const ReelsNextPageRequested();
}

/// A specific item's video failed to open — swiping past it must not be
/// blocked, and the user can retry that single item (FR-035).
class ReelsItemRetryRequested extends ReelsFeedEvent {
  const ReelsItemRetryRequested(this.index);

  final int index;

  @override
  List<Object?> get props => [index];
}

/// Internal — dispatched by [ReelsPlayerPool.onOpenError] (a plain
/// callback, not an event handler) so the failure can be applied via
/// `emit()` inside the bloc's own event-handling flow.
class ReelsItemOpenFailed extends ReelsFeedEvent {
  const ReelsItemOpenFailed(this.index);

  final int index;

  @override
  List<Object?> get props => [index];
}

/// Full teardown for the global logout sequence (constitution V-A) — unlike
/// [ReelsRefreshRequested], this returns the bloc to its pristine [initial]
/// state (no reels, no cursor, no scope) so the next login's first Reels
/// tab visit triggers a genuinely fresh load rather than resuming stale data.
class ReelsFeedReset extends ReelsFeedEvent {
  const ReelsFeedReset();
}
