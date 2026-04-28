import 'dart:io';

import 'package:ciro_chat_app/features/chat/domain/entities/chat_session.dart';
import 'package:injectable/injectable.dart';
import 'package:ciro_chat_app/features/chat/domain/entities/message.dart';
import 'package:ciro_chat_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:ciro_chat_app/features/chat/data/datasources/chat_remote_data_source.dart';
import 'package:fpdart/fpdart.dart';
import 'package:ciro_chat_app/core/error/failures.dart';

@LazySingleton(as: ChatRepository)
class ChatRepositoryImpl implements ChatRepository {
  final ChatRemoteDataSource remoteDataSource;

  ChatRepositoryImpl(this.remoteDataSource);

  @override
  Future<void> connect() async {
    await remoteDataSource.connect();
  }

  @override
  Future<void> disconnect() async {
    await remoteDataSource.disconnect();
  }

  @override
  Future<void> sendMessage(String text) async {
    remoteDataSource.sendMessage(text);
  }

  @override
  Stream<Message> get messageStream => remoteDataSource.messageStream;

  @override
  Future<Either<Failure, String>> createPrivateChatRoom(String targetUserId) {
    return remoteDataSource.createPrivateChatRoom(targetUserId);
  }

  @override
  Future<Either<Failure, Map<String, String>>> syncMessageStatuses(
    List<String> clientMessageIds,
  ) {
    return remoteDataSource.syncMessageStatuses(clientMessageIds);
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> uploadFile(File file) {
    return remoteDataSource.uploadFile(file);
  }

  @override
  Future<Either<Failure, List<ChatSession>>> fetchRooms() {
    return remoteDataSource.fetchRooms();
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> createGroup(
    String groupName,
    List<String> participants,
    String? avatarUrl,
  ) {
    return remoteDataSource.createGroup(groupName, participants, avatarUrl);
  }

  @override
  Future<Either<Failure, void>> addParticipants(
    String roomId,
    List<String> participants,
  ) {
    return remoteDataSource.addParticipants(roomId, participants);
  }

  @override
  Future<Either<Failure, void>> removeParticipant(
    String roomId,
    String participantId,
  ) {
    return remoteDataSource.removeParticipant(roomId, participantId);
  }

  @override
  Future<Either<Failure, void>> leaveGroup(String roomId) {
    return remoteDataSource.leaveGroup(roomId);
  }

  @override
  Future<Either<Failure, void>> blockUser(String targetUserId) {
    return remoteDataSource.blockUser(targetUserId);
  }

  @override
  Future<Either<Failure, void>> unblockUser(String targetUserId) {
    return remoteDataSource.unblockUser(targetUserId);
  }

  @override
  Future<Either<Failure, List<String>>> getBlockList() {
    return remoteDataSource.getBlockList();
  }

  @override
  Future<Either<Failure, List<Message>>> fetchRoomMessages(String roomId) {
    return remoteDataSource.fetchRoomMessages(roomId);
  }
}
