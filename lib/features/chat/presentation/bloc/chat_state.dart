part of 'chat_cubit.dart';

abstract class ChatState extends Equatable {
  const ChatState();

  @override
  List<Object> get props => [];
}

class ChatInitial extends ChatState {}

class ChatLoading extends ChatState {}

class ChatRoomActive extends ChatState {
  final String roomId;
  final List<Message> messages;

  const ChatRoomActive(this.roomId, this.messages);

  @override
  List<Object> get props => [roomId, messages];
}

class ChatError extends ChatState {
  final String message;
  const ChatError(this.message);

  @override
  List<Object> get props => [message];
}

class ChatConnecting extends ChatState {}
class ChatConnected extends ChatState {
  final List<Message> messages;
  const ChatConnected(this.messages);
  @override
  List<Object> get props => [messages];
}

class ChatContactsSynced extends ChatState {
  final List<ChatSession> syncedContacts;
  const ChatContactsSynced(this.syncedContacts);

  @override
  List<Object> get props => [syncedContacts];
}
