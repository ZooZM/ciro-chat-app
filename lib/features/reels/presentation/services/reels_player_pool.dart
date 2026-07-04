import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/reel.dart';
import 'package:ciro_chat_app/features/reels/reels_constants.dart';

/// Maintains a strict sliding window of at most [ReelsConstants.maxLivePlayers]
/// live `media_kit` players — `{current-1, current, current+1}` — so memory
/// stays bounded regardless of session length (FR-013).
///
/// All player lifecycle operations (open/play/pause/dispose) run
/// fire-and-forget off the calling frame: `syncWindow` never awaits a
/// player operation before returning, so a swipe never blocks on video I/O
/// (FR-011). Eviction always happens before creation of new window members.
@lazySingleton
class ReelsPlayerPool {
  final Map<int, Player> _players = {};
  final Map<int, VideoController> _controllers = {};
  final Map<int, StreamSubscription<String>> _errorSubs = {};

  /// Called with the index whose player failed to open or play (FR-035).
  /// Covers three distinct failure modes: `open()` itself rejecting (e.g. a
  /// malformed URL), a playback error arriving on `player.stream.error`
  /// *after* `open()` already resolved (e.g. the network fetch failing), and
  /// a player that never leaves the buffering state at all (timeout below).
  void Function(int index, Object error)? onOpenError;

  VideoController? controllerFor(int index) => _controllers[index];

  bool get isEmpty => _players.isEmpty;

  /// Rebuilds the live-player window around [currentIndex] and ensures only
  /// that index is playing. Fire-and-forget by design (see class doc).
  void syncWindow(int currentIndex, List<Reel> reels) {
    if (reels.isEmpty) return;

    final window = <int>{
      if (currentIndex - 1 >= 0) currentIndex - 1,
      if (currentIndex >= 0 && currentIndex < reels.length) currentIndex,
      if (currentIndex + 1 < reels.length) currentIndex + 1,
    };

    // Evict first — never let the window exceed maxLivePlayers.
    final toEvict = _players.keys.where((k) => !window.contains(k)).toList();
    for (final index in toEvict) {
      _evictPlayer(index);
    }

    for (final index in window) {
      if (_players.containsKey(index)) continue;
      final player = Player(
        configuration: PlayerConfiguration(bufferSize: ReelsConstants.playerBufferSizeBytes),
      );
      _players[index] = player;
      _controllers[index] = VideoController(player);
      _watchForFailures(index, player);
      // Loop the single loaded reel indefinitely instead of stopping dead at
      // the end — matches the auto-play/loop convention of every short-video
      // feed (TikTok/Reels/Shorts).
      unawaited(player.setPlaylistMode(PlaylistMode.single));
      unawaited(
        player
            .open(Media(reels[index].videoUrl), play: index == currentIndex)
            .catchError((Object error, StackTrace _) {
          if (_players[index] == player) onOpenError?.call(index, error);
        }),
      );
    }

    for (final entry in _players.entries) {
      if (entry.key == currentIndex) {
        unawaited(entry.value.play());
      } else {
        unawaited(entry.value.pause());
      }
    }

    assert(
      _players.length <= ReelsConstants.maxLivePlayers,
      'Reels player window exceeded ${ReelsConstants.maxLivePlayers} live players: ${_players.length}',
    );
  }

  /// Wires the two failure-detection paths that `open()`'s own `catchError`
  /// can't cover, since `open()` resolves once the command is *accepted*,
  /// not once the media has actually finished loading:
  ///  1. `player.stream.error` — an explicit error from the native backend
  ///     (e.g. an unreachable/404 video URL) arriving after `open()` resolved.
  ///  2. A buffering timeout — some failures (a silently unreachable host)
  ///     never emit an explicit error and never leave the buffering state;
  ///     without this, [BufferingIndicator] would spin forever (FR-035).
  /// Both guard against firing for a stale/evicted player via the
  /// `_players[index] == player` identity check — an index gets reused for
  /// a different player as the window slides.
  void _watchForFailures(int index, Player player) {
    final errorSub = player.stream.error.listen((message) {
      if (_players[index] == player) onOpenError?.call(index, message);
    });
    _errorSubs[index] = errorSub;

    unawaited(
      player.stream.buffering.firstWhere((buffering) => !buffering).timeout(
        ReelsConstants.bufferingTimeout,
        onTimeout: () {
          if (_players[index] == player) {
            onOpenError?.call(index, 'Timed out waiting for video to buffer');
          }
          return true;
        },
      ).then((_) {
        // The video left the buffering state at least once, proving it can
        // load — stop treating further `error` messages as fatal from here
        // on. mpv's error stream can emit transient, self-recovering
        // diagnostics during normal playback (e.g. a brief network blip);
        // without this, one of those would retroactively flag an
        // already-working video as failed.
        if (_errorSubs[index] == errorSub) {
          _errorSubs.remove(index);
        }
        unawaited(errorSub.cancel());
      }),
    );
  }

  void _evictPlayer(int index) {
    final player = _players.remove(index);
    _controllers.remove(index);
    unawaited(_errorSubs.remove(index)?.cancel());
    if (player != null) unawaited(player.dispose());
  }

  /// Disposes the player at [index] (if any) so a subsequent [syncWindow]
  /// recreates it from scratch — used to retry a failed item (FR-035).
  void evict(int index) => _evictPlayer(index);

  Future<void> togglePlayPause(int index) async {
    final player = _players[index];
    if (player == null) return;
    await player.playOrPause();
  }

  /// Pauses every live player without disposing them (FR-004: tab switch /
  /// app background). Resuming plays only the last-current index — the
  /// caller re-invokes [syncWindow] with the preserved index on return.
  void pauseAll() {
    for (final player in _players.values) {
      unawaited(player.pause());
    }
  }

  void resumeCurrent(int currentIndex) {
    final player = _players[currentIndex];
    if (player != null) unawaited(player.play());
  }

  /// Full teardown — logout, feed reset, or widget disposal (constitution V).
  void disposeAll() {
    final indices = _players.keys.toList();
    for (final index in indices) {
      _evictPlayer(index);
    }
  }

  @visibleForTesting
  int get liveWindowSizeForTest => _players.length;
}
