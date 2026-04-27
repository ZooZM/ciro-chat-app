import 'dart:io';

import 'package:ciro_chat_app/features/chat/domain/entities/chat_session.dart';
import 'package:ciro_chat_app/features/chat/domain/entities/message.dart';
import 'package:fpdart/fpdart.dart';
import 'package:ciro_chat_app/core/error/failures.dart';

abstract class ChatRepository {
  Future<void> connect();
  Future<void> disconnect();
  Future<void> sendMessage(String text);
  Stream<Message> get messageStream;

  Future<Either<Failure, String>> createPrivateChatRoom(String targetUserId);
  Future<Either<Failure, Map<String, String>>> syncMessageStatuses(
    List<String> clientMessageIds,
  );
  Future<Either<Failure, Map<String, dynamic>>> uploadFile(File file);
  Future<Either<Failure, List<ChatSession>>> fetchRooms();

  // New group chat methods
  Future<Either<Failure, Map<String, dynamic>>> createGroup(
    String groupName,
    List<String> participants,
    String? avatarUrl,
  );
  Future<Either<Failure, void>> addParticipants(
    String roomId,
    List<String> participants,
  );
  Future<Either<Failure, void>> removeParticipant(
    String roomId,
    String participantId,
  );
  Future<Either<Failure, void>> leaveGroup(String roomId);

  // Block User API endpoints
  Future<Either<Failure, void>> blockUser(String targetUserId);
  Future<Either<Failure, void>> unblockUser(String targetUserId);
  Future<Either<Failure, List<String>>> getBlockList();
}
