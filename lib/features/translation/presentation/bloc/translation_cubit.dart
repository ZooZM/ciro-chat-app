import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../domain/entities/caption.dart';
import '../../domain/entities/translation_subscription.dart';
import '../../domain/repositories/translation_repository.dart';
import 'translation_state.dart';

/// Fallback target language (spec Assumptions) when the listener's
/// device/app language isn't in the supported-languages list.
const _kFallbackTargetLanguage = 'en';

/// Transient signals for the UI to react to once (not persisted in
/// [TranslationState]) — precedent: `CallSideEvent` in `call_cubit.dart`.
sealed class TranslationSideEvent {}

/// FR-001/US3: a subscribe/unsubscribe/changeLanguage emit could not be
/// dispatched (e.g. socket disconnected) — show a non-blocking SnackBar
/// (Constitution VII).
class TranslationSocketError extends TranslationSideEvent {
  final String speakerId;
  TranslationSocketError(this.speakerId);
}

/// Per-speaker high-water mark for FR-012 stale/out-of-order suppression.
class _SegmentTracker {
  final String segmentId;
  final int seq;
  final CaptionType type;
  const _SegmentTracker(this.segmentId, this.seq, this.type);
}

@injectable
class TranslationCubit extends Cubit<TranslationState> {
  final TranslationRepository _repository;

  String? _roomId;
  StreamSubscription<Caption>? _captionSubscription;

  // Auto-retry timers for `language_undetected` — keyed by speakerId.
  final Map<String, Timer> _retryTimers = {};

  /// Per-speaker caption hot path — NOT part of [TranslationState]
  /// (data-model.md §5). Caption updates call `.value =`, never `emit()`.
  final Map<String, ValueNotifier<Caption?>> _captionNotifiers = {};
  final ValueNotifier<Caption?> latestActiveCaption = ValueNotifier(null);
  final Map<String, _SegmentTracker> _lastApplied = {};

  final _sideEventController = StreamController<TranslationSideEvent>.broadcast();
  Stream<TranslationSideEvent> get sideEvents => _sideEventController.stream;

  TranslationCubit(this._repository) : super(const TranslationState()) {
    _repository.onSubscribed = (speakerId, targetLanguage, remainingSeconds) {
      _updateSubscription(
        speakerId,
        (sub) => sub.copyWith(
          status: TranslationStatus.active,
          targetLanguage: targetLanguage,
          clearDeniedReason: true,
          clearUnavailableReason: true,
        ),
      );
    };

    _repository.onUnsubscribed = (_) {
      // Informational only — local state already transitioned to `off` in
      // unsubscribe() / removeSpeaker().
    };

    _repository.onDenied = (speakerId, reason) {
      _updateSubscription(
        speakerId,
        (sub) => sub.copyWith(status: TranslationStatus.denied, deniedReason: reason),
      );
    };

    _repository.onUnavailable = (speakerId, reason, transient) {
      // `language_undetected` means STT timed out waiting for speech — the
      // speaker will talk again. Auto-retry keeps the CC toggle live so the
      // user never has to manually cycle the button.
      if (reason == 'language_undetected') {
        _scheduleRetry(speakerId);
      } else {
        _updateSubscription(
          speakerId,
          (sub) => sub.copyWith(
            status: TranslationStatus.unavailable,
            unavailableReason: reason,
          ),
        );
      }
    };

    _repository.addReconnectListener(_onReconnect);
  }

  /// Lazily creates (or returns) the per-speaker caption notifier
  /// (data-model.md §5).
  ValueNotifier<Caption?> captionNotifier(String speakerId) =>
      _captionNotifiers.putIfAbsent(speakerId, () => ValueNotifier(null));

  /// FR-001/research.md §2: subscribes to the data layer's `Stream<Caption>`
  /// for [room]. The UI never wires a `DataReceivedEvent` handler itself.
  void attachRoom(Room room, {required String roomId}) {
    _roomId = roomId;
    _captionSubscription?.cancel();
    _captionSubscription = _repository.attachRoom(room).listen(_onCaption);
  }

  /// Cancels the caption stream subscription (Constitution V). Does not
  /// touch `subscriptions` — that's handled by `close()`.
  void detachRoom() {
    _captionSubscription?.cancel();
    _captionSubscription = null;
  }

  void _onCaption(Caption caption) {
    final speakerId = caption.speakerId;
    final sub = state.subscriptions[speakerId];
    if (sub == null) {
      debugPrint('[TranslationCubit] DROPPED — no subscription for speakerId="$speakerId". Active subscriptions: ${state.subscriptions.keys.toList()}');
      return;
    }
    if (caption.targetLanguage != sub.targetLanguage) {
      debugPrint('[TranslationCubit] DROPPED — language mismatch for speakerId="$speakerId": packet.targetLanguage="${caption.targetLanguage}" ≠ subscription.targetLanguage="${sub.targetLanguage}"');
      return;
    }

    final tracker = _lastApplied[speakerId];
    final accept = tracker == null ||
        tracker.segmentId != caption.segmentId ||
        caption.type == CaptionType.final_ ||
        caption.seq >= tracker.seq;
    if (!accept) {
      debugPrint('[TranslationCubit] DROPPED stale — speakerId="$speakerId" segmentId="${caption.segmentId}" seq=${caption.seq} (tracked: segId="${tracker.segmentId}" seq=${tracker.seq} type=${tracker.type})');
      return;
    }

    debugPrint('[TranslationCubit] ACCEPTED — speakerId="$speakerId" type=${caption.type} text="${caption.text}"');
    _lastApplied[speakerId] = _SegmentTracker(caption.segmentId, caption.seq, caption.type);
    captionNotifier(speakerId).value = caption;
    latestActiveCaption.value = caption;
  }

  /// FR-001: enables translation for [speakerId] into [targetLanguage].
  /// Advances to `pending` only on a successful dispatch (`Right`); on
  /// `Left` the prior status is left unchanged and a [TranslationSocketError]
  /// side event is emitted (Constitution VII).
  void subscribe({required String speakerId, required String targetLanguage}) {
    final roomId = _roomId;
    if (roomId == null) return;
    _repository
        .subscribe(roomId: roomId, speakerId: speakerId, targetLanguage: targetLanguage)
        .match(
          (_) => _sideEventController.add(TranslationSocketError(speakerId)),
          (_) {
            final updated = Map<String, TranslationSubscription>.from(state.subscriptions);
            updated[speakerId] = TranslationSubscription(
              speakerId: speakerId,
              targetLanguage: targetLanguage,
              status: TranslationStatus.pending,
            );
            emit(state.copyWith(subscriptions: updated));
          },
        );
  }

  /// FR-002/FR-013: disables translation for [speakerId], clearing its
  /// caption notifier and removing it from [TranslationState.subscriptions].
  void unsubscribe(String speakerId) {
    final roomId = _roomId;
    if (roomId == null) return;
    _repository.unsubscribe(roomId: roomId, speakerId: speakerId).match(
      (_) => _sideEventController.add(TranslationSocketError(speakerId)),
      (_) => _clearSpeaker(speakerId),
    );
  }

  /// US3: re-points [speakerId]'s translation to [targetLanguage], re-entering
  /// `pending` until the next `translation:subscribed`.
  void changeLanguage({required String speakerId, required String targetLanguage}) {
    final roomId = _roomId;
    final current = state.subscriptions[speakerId];
    if (roomId == null || current == null) return;
    _repository
        .changeLanguage(roomId: roomId, speakerId: speakerId, targetLanguage: targetLanguage)
        .match(
          (_) => _sideEventController.add(TranslationSocketError(speakerId)),
          (_) {
            final updated = Map<String, TranslationSubscription>.from(state.subscriptions);
            updated[speakerId] = current.copyWith(
              targetLanguage: targetLanguage,
              status: TranslationStatus.pending,
              clearDeniedReason: true,
              clearUnavailableReason: true,
            );
            emit(state.copyWith(subscriptions: updated));
          },
        );
  }

  /// FR-001/US3: resolves the target language to pre-select when a listener
  /// opens the toggle for [speakerId] — the speaker's existing selection if
  /// any, else [deviceLanguageCode] if supported, else the configured
  /// fallback ("en").
  String resolveTargetLanguage(
    String speakerId, {
    required String deviceLanguageCode,
    required List<String> supportedLanguages,
  }) {
    final existing = state.subscriptions[speakerId]?.targetLanguage;
    if (existing != null) return existing;
    if (supportedLanguages.contains(deviceLanguageCode)) return deviceLanguageCode;
    return _kFallbackTargetLanguage;
  }

  /// FR-013: local cleanup when [speakerId] leaves the call — removes its
  /// subscription entry, disposes/clears its caption notifier, and
  /// best-effort emits `translation:unsubscribe`.
  void removeSpeaker(String speakerId) {
    final sub = state.subscriptions[speakerId];
    if (sub == null) return;
    final roomId = _roomId;
    if (roomId != null && _isLive(sub.status)) {
      _repository.unsubscribe(roomId: roomId, speakerId: speakerId);
    }
    _clearSpeaker(speakerId);
  }

  void _clearSpeaker(String speakerId) {
    _retryTimers.remove(speakerId)?.cancel();
    final updated = Map<String, TranslationSubscription>.from(state.subscriptions)
      ..remove(speakerId);
    emit(state.copyWith(subscriptions: updated));
    _captionNotifiers.remove(speakerId)?.dispose();
    _lastApplied.remove(speakerId);
    if (latestActiveCaption.value?.speakerId == speakerId) {
      latestActiveCaption.value = null;
    }
  }

  /// FR-016: on socket reconnect, re-emits `translation:subscribe` for every
  /// speaker that was `pending`/`active`/`unavailable` before the drop, using
  /// their last-selected `targetLanguage`, and sets `status = pending`.
  void _onReconnect() {
    final roomId = _roomId;
    if (roomId == null) return;
    final updated = <String, TranslationSubscription>{};
    for (final entry in state.subscriptions.entries) {
      final sub = entry.value;
      if (_isLive(sub.status)) {
        _repository.subscribe(
          roomId: roomId,
          speakerId: entry.key,
          targetLanguage: sub.targetLanguage,
        );
        updated[entry.key] = sub.copyWith(
          status: TranslationStatus.pending,
          clearUnavailableReason: true,
        );
      } else {
        updated[entry.key] = sub;
      }
    }
    emit(state.copyWith(subscriptions: updated));
  }

  /// Schedules a silent re-subscribe for [speakerId] after 2 seconds.
  /// Called when `translation_unavailable` arrives with `language_undetected`
  /// — the speaker was silent and STT timed out; status stays `active` so
  /// the CC toggle stays lit and the user sees no interruption.
  void _scheduleRetry(String speakerId) {
    _retryTimers[speakerId]?.cancel();
    _retryTimers[speakerId] = Timer(const Duration(seconds: 2), () {
      _retryTimers.remove(speakerId);
      final sub = state.subscriptions[speakerId];
      final roomId = _roomId;
      if (sub == null || roomId == null || !_isLive(sub.status)) return;
      _repository
          .subscribe(
            roomId: roomId,
            speakerId: speakerId,
            targetLanguage: sub.targetLanguage,
          )
          .fold(
            (_) => _updateSubscription(
              speakerId,
              (s) => s.copyWith(
                status: TranslationStatus.unavailable,
                unavailableReason: 'language_undetected',
              ),
            ),
            (_) {
              // Emit dispatched — status stays active; next `subscribed` ACK
              // confirms the retry. No state change needed here.
            },
          );
    });
  }

  bool _isLive(TranslationStatus status) =>
      status == TranslationStatus.pending ||
      status == TranslationStatus.active ||
      status == TranslationStatus.unavailable;

  void _updateSubscription(
    String speakerId,
    TranslationSubscription Function(TranslationSubscription) update,
  ) {
    final current = state.subscriptions[speakerId];
    if (current == null) return;
    final updated = Map<String, TranslationSubscription>.from(state.subscriptions);
    updated[speakerId] = update(current);
    emit(state.copyWith(subscriptions: updated));
  }

  @override
  Future<void> close() {
    if (isClosed) return super.close();

    _captionSubscription?.cancel();
    for (final t in _retryTimers.values) {
      t.cancel();
    }
    _retryTimers.clear();
    _repository.removeReconnectListener(_onReconnect);

    final roomId = _roomId;
    if (roomId != null) {
      for (final entry in state.subscriptions.entries) {
        if (_isLive(entry.value.status)) {
          _repository.unsubscribe(roomId: roomId, speakerId: entry.key);
        }
      }
    }

    for (final notifier in _captionNotifiers.values) {
      notifier.dispose();
    }
    latestActiveCaption.dispose();
    _sideEventController.close();
    return super.close();
  }
}
