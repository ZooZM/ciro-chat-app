import 'package:ciro_chat_app/core/network/socket_service.dart';
import 'package:ciro_chat_app/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:ciro_chat_app/features/chat/data/datasources/chat_local_data_source.dart';
import 'package:ciro_chat_app/features/status/data/datasources/status_local_data_source.dart';
import 'package:ciro_chat_app/features/status/data/datasources/status_remote_data_source.dart';
import 'package:ciro_chat_app/features/status/domain/repositories/status_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockStatusRepository extends Mock implements StatusRepository {}

class MockStatusLocalDataSource extends Mock implements StatusLocalDataSource {}

class MockStatusRemoteDataSource extends Mock implements StatusRemoteDataSource {}

class MockAuthLocalDataSource extends Mock implements AuthLocalDataSource {}

class MockSocketService extends Mock implements SocketService {}

class MockChatLocalDataSource extends Mock implements ChatLocalDataSource {}
