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
  /// IDs of users blocked by the current user. Part of state so the UI
  /// rebuilds reactively via [BlocBuilder] without any [ValueNotifier].
  final List<String> blockedUserIds;
  /// FR-018: Pagination state for infinite scroll.
  final bool isLoadingMore;
  final bool hasMoreMessages;

  const ChatRoomActive(
    this.roomId,
    this.messages, {
    this.blockedUserIds = const [],
    this.isLoadingMore = false,
    this.hasMoreMessages = true,
  });

  /// Surgical update: copies the state, replacing only the provided fields.
  /// The [Equatable] props include [messages], so BlocBuilder rebuilds ONLY
  /// when the message list reference actually changes (new snapshot from SQLite).
  ChatRoomActive copyWith({
    String? roomId,
    List<Message>? messages,
    List<String>? blockedUserIds,
    bool? isLoadingMore,
    bool? hasMoreMessages,
  }) {
    return ChatRoomActive(
      roomId ?? this.roomId,
      messages ?? this.messages,
      blockedUserIds: blockedUserIds ?? this.blockedUserIds,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMoreMessages: hasMoreMessages ?? this.hasMoreMessages,
    );
  }

  @override
  List<Object> get props => [roomId, messages, blockedUserIds, isLoadingMore, hasMoreMessages];
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

// ─────────────────────────────────────────────────────────────────────────────
// Block update — lightweight surgical state for block/unblock operations.
//
// Emitted after blockUser() / unblockUser() succeed. Contains the FULL
// updated blocked-user list so any listening widget can rebuild selectively:
//
//   BlocBuilder<ChatCubit, ChatState>(
//     buildWhen: (prev, curr) => curr is ChatBlockUpdated,
//     builder: (ctx, state) {
//       final blocked = state is ChatBlockUpdated ? state.blockedUserIds : [];
//       ...
//     },
//   )
// ─────────────────────────────────────────────────────────────────────────────

class ChatBlockUpdated extends ChatState {
  /// The full list of blocked user IDs after the operation.
  final List<String> blockedUserIds;

  const ChatBlockUpdated(this.blockedUserIds);

  @override
  List<Object> get props => [blockedUserIds];
}
