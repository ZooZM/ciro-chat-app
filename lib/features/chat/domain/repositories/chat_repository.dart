import 'package:ciro_chat_app/features/chat/domain/entities/message.dart';

abstract class ChatRepository {
  Future<void> connect();
  Future<void> disconnect();
  Future<void> sendMessage(String text);
  Stream<Message> get messageStream;
}
