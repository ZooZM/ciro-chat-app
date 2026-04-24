part of 'chat_cubit.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Base
// ─────────────────────────────────────────────────────────────────────────────

abstract class ChatState extends Equatable {
  const ChatState();

  @override
  List<Object> get props => [];
}

// ─────────────────────────────────────────────────────────────────────────────
// Lifecycle states
// ─────────────────────────────────────────────────────────────────────────────

class ChatInitial extends ChatState {}

class ChatLoading extends ChatState {}

class ChatConnecting extends ChatState {}

class ChatConnected extends ChatState {
  final List<Message> messages;
  const ChatConnected(this.messages);
  @override
  List<Object> get props => [messages];
}

class ChatError extends ChatState {
  final String message;
  const ChatError(this.message);

  @override
  List<Object> get props => [message];
}

class ChatContactsSynced extends ChatState {
  final List<ChatSession> syncedContacts;
  const ChatContactsSynced(this.syncedContacts);

  @override
  List<Object> get props => [syncedContacts];
}

// ─────────────────────────────────────────────────────────────────────────────
// Active room — primary message-list state
// ─────────────────────────────────────────────────────────────────────────────

class ChatRoomActive extends ChatState {
  final String roomId;
  final List<Message> messages;

  const ChatRoomActive(this.roomId, this.messages);

  /// Surgical update: copies the state, replacing only the provided fields.
  /// The [Equatable] props include [messages], so BlocBuilder rebuilds ONLY
  /// when the message list reference actually changes (new snapshot from SQLite).
  ChatRoomActive copyWith({
    String? roomId,
    List<Message>? messages,
  }) {
    return ChatRoomActive(
      roomId ?? this.roomId,
      messages ?? this.messages,
    );
  }

  @override
  List<Object> get props => [roomId, messages];
}

// ─────────────────────────────────────────────────────────────────────────────
// Typing update — lightweight state that carries ONLY typing info.
//
// By making this a distinct state (instead of inlining typing into
// ChatRoomActive), any widget that only cares about messages can use:
//
//   BlocBuilder<ChatCubit, ChatState>(
//     buildWhen: (prev, curr) => curr is! TypingUpdate,
//     builder: …,
//   )
//
// …and will be completely immune to typing events.
// ─────────────────────────────────────────────────────────────────────────────

class TypingUpdate extends ChatState {
  /// The room this typing event belongs to.
  final String roomId;

  /// Current set of user identifiers (phone or userId) that are typing.
  final Set<String> typingUsers;

  const TypingUpdate({required this.roomId, required this.typingUsers});

  @override
  List<Object> get props => [roomId, typingUsers];
}
