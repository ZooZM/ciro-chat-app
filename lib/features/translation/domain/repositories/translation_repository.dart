import 'package:fpdart/fpdart.dart';
import 'package:livekit_client/livekit_client.dart';
import '../../../../core/error/failures.dart';
import '../entities/caption.dart';

/// Translation feature data boundary (Constitution I) — the presentation
/// layer only ever sees [Caption] entities and [Either]/callback results,
/// never raw `DataReceivedEvent`s or socket payloads.
abstract class TranslationRepository {
  /// Begins listening for caption packets on [room]'s data channel.
  /// Returns a stream of parsed captions already filtered to
  /// `topic == "translation"`. The data layer owns the underlying LiveKit
  /// listener.
  Stream<Caption> attachRoom(Room room);

  /// Sends `translation:subscribe`. `Left(SocketFailure)` if the emit cannot
  /// be dispatched (e.g. socket disconnected); `Right(unit)` on successful
  /// dispatch. The eventual outcome arrives via [onSubscribed]/[onDenied].
  Either<Failure, Unit> subscribe({
    required String roomId,
    required String speakerId,
    required String targetLanguage,
  });

  /// Sends `translation:unsubscribe`.
  Either<Failure, Unit> unsubscribe({
    required String roomId,
    required String speakerId,
  });

  /// Sends `translation:changeLanguage`.
  Either<Failure, Unit> changeLanguage({
    required String roomId,
    required String speakerId,
    required String targetLanguage,
  });

  /// `translation:subscribed` — `pending -> active`.
  set onSubscribed(
    void Function(String speakerId, String targetLanguage, int remainingSeconds)? cb,
  );

  /// `translation:unsubscribed` — confirms `-> off` (informational only).
  set onUnsubscribed(void Function(String speakerId)? cb);

  /// `translation:denied` — `pending -> denied`.
  set onDenied(void Function(String speakerId, String reason)? cb);

  /// `translation_unavailable` — `active -> unavailable`.
  set onUnavailable(
    void Function(String speakerId, String reason, bool transient)? cb,
  );

  /// FR-016 reconnect auto-resume — forwards `SocketService`'s multicast
  /// reconnect API so the Cubit never touches `SocketService` directly.
  void addReconnectListener(void Function() cb);

  void removeReconnectListener(void Function() cb);
}
