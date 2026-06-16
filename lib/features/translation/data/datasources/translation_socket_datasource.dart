import 'package:injectable/injectable.dart';

import '../../../../core/network/socket_service.dart';

/// Wraps [SocketService] so `TranslationCubit` never touches it directly
/// (Constitution IV — one singleton `SocketService`).
@injectable
class TranslationSocketDataSource {
  final SocketService _socketService;

  TranslationSocketDataSource(this._socketService);

  void subscribe({
    required String roomId,
    required String speakerId,
    required String targetLanguage,
  }) {
    _socketService.emitTranslationSubscribe(
      roomId: roomId,
      speakerId: speakerId,
      targetLanguage: targetLanguage,
    );
  }

  void unsubscribe({required String roomId, required String speakerId}) {
    _socketService.emitTranslationUnsubscribe(roomId: roomId, speakerId: speakerId);
  }

  void changeLanguage({
    required String roomId,
    required String speakerId,
    required String targetLanguage,
  }) {
    _socketService.emitTranslationChangeLanguage(
      roomId: roomId,
      speakerId: speakerId,
      targetLanguage: targetLanguage,
    );
  }

  set onSubscribed(
    void Function(String speakerId, String targetLanguage, int remainingSeconds)? cb,
  ) {
    _socketService.onTranslationSubscribed = cb;
  }

  set onUnsubscribed(void Function(String speakerId)? cb) {
    _socketService.onTranslationUnsubscribed = cb;
  }

  set onDenied(void Function(String speakerId, String reason)? cb) {
    _socketService.onTranslationDenied = cb;
  }

  set onUnavailable(void Function(String speakerId, String reason, bool transient)? cb) {
    _socketService.onTranslationUnavailable = cb;
  }

  void addReconnectListener(void Function() cb) {
    _socketService.addReconnectListener(cb);
  }

  void removeReconnectListener(void Function() cb) {
    _socketService.removeReconnectListener(cb);
  }

  /// Synchronous connectivity check — used by `TranslationRepositoryImpl` to
  /// determine `Left(SocketFailure)` vs `Right(unit)`.
  bool get isConnected => _socketService.isConnected;
}
