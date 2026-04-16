import 'package:injectable/injectable.dart';
import 'package:ciro_chat_app/features/chat/domain/entities/message.dart';
import 'package:ciro_chat_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:ciro_chat_app/features/chat/data/datasources/chat_remote_data_source.dart';

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
}
