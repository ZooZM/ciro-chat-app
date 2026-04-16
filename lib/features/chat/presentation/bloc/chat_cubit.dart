import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';
import 'package:ciro_chat_app/features/chat/domain/entities/message.dart';
import 'package:ciro_chat_app/features/chat/domain/repositories/chat_repository.dart';

part 'chat_state.dart';

@injectable
class ChatCubit extends Cubit<ChatState> {
  final ChatRepository _chatRepository;
  StreamSubscription<Message>? _messageSubscription;
  final List<Message> _messages = [];

  ChatCubit(this._chatRepository) : super(ChatInitial());

  Future<void> connectToChat() async {
    emit(ChatConnecting());
    try {
      await _chatRepository.connect();
      
      _messageSubscription?.cancel();
      _messageSubscription = _chatRepository.messageStream.listen(
        (message) {
          _messages.add(message);
          emit(ChatConnected(List.from(_messages)));
        },
        onError: (error) {
          emit(ChatError(error.toString()));
        },
      );
      
      // If we connect, we emit connected with empty/current messages
      emit(ChatConnected(List.from(_messages)));
    } catch (e) {
      emit(ChatError(e.toString()));
    }
  }

  Future<void> sendMessage(String text) async {
    if (state is ChatConnected) {
      await _chatRepository.sendMessage(text);
    }
  }

  Future<void> disconnect() async {
    _messageSubscription?.cancel();
    await _chatRepository.disconnect();
    _messages.clear();
    emit(ChatInitial());
  }

  @override
  Future<void> close() {
    _messageSubscription?.cancel();
    _chatRepository.disconnect();
    return super.close();
  }
}
