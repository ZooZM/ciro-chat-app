import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/caption.dart';
import '../../domain/repositories/translation_repository.dart';
import '../datasources/translation_data_channel_datasource.dart';
import '../datasources/translation_socket_datasource.dart';

@LazySingleton(as: TranslationRepository)
class TranslationRepositoryImpl implements TranslationRepository {
  final TranslationDataChannelDataSource _dataChannelDataSource;
  final TranslationSocketDataSource _socketDataSource;

  TranslationRepositoryImpl(this._dataChannelDataSource, this._socketDataSource);

  @override
  Stream<Caption> attachRoom(Room room) => _dataChannelDataSource.attach(room);

  @override
  Either<Failure, Unit> subscribe({
    required String roomId,
    required String speakerId,
    required String targetLanguage,
  }) {
    if (!_socketDataSource.isConnected) return Left(const SocketFailure());
    _socketDataSource.subscribe(
      roomId: roomId,
      speakerId: speakerId,
      targetLanguage: targetLanguage,
    );
    return Right(unit);
  }

  @override
  Either<Failure, Unit> unsubscribe({required String roomId, required String speakerId}) {
    if (!_socketDataSource.isConnected) return Left(const SocketFailure());
    _socketDataSource.unsubscribe(roomId: roomId, speakerId: speakerId);
    return Right(unit);
  }

  @override
  Either<Failure, Unit> changeLanguage({
    required String roomId,
    required String speakerId,
    required String targetLanguage,
  }) {
    if (!_socketDataSource.isConnected) return Left(const SocketFailure());
    _socketDataSource.changeLanguage(
      roomId: roomId,
      speakerId: speakerId,
      targetLanguage: targetLanguage,
    );
    return Right(unit);
  }

  @override
  set onSubscribed(
    void Function(String speakerId, String targetLanguage, int remainingSeconds)? cb,
  ) {
    _socketDataSource.onSubscribed = cb;
  }

  @override
  set onUnsubscribed(void Function(String speakerId)? cb) {
    _socketDataSource.onUnsubscribed = cb;
  }

  @override
  set onDenied(void Function(String speakerId, String reason)? cb) {
    _socketDataSource.onDenied = cb;
  }

  @override
  set onUnavailable(void Function(String speakerId, String reason, bool transient)? cb) {
    _socketDataSource.onUnavailable = cb;
  }

  @override
  void addReconnectListener(void Function() cb) {
    _socketDataSource.addReconnectListener(cb);
  }

  @override
  void removeReconnectListener(void Function() cb) {
    _socketDataSource.removeReconnectListener(cb);
  }
}
