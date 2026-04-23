import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ciro_chat_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:ciro_chat_app/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:ciro_chat_app/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:ciro_chat_app/core/network/socket_service.dart';
import 'package:ciro_chat_app/features/chat/presentation/bloc/chat_cubit.dart';
import 'package:ciro_chat_app/features/video_call/presentation/bloc/call_cubit.dart';
import 'package:ciro_chat_app/features/chat/data/datasources/chat_local_data_source.dart';

class MockAuthRepository extends Mock implements AuthRepository {}
class MockAuthRemoteDataSource extends Mock implements AuthRemoteDataSource {}
class MockAuthLocalDataSource extends Mock implements AuthLocalDataSource {}
class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}
class MockDio extends Mock implements Dio {}
class MockResponse extends Mock implements Response {}
class MockSocketService extends Mock implements SocketService {}
class MockChatCubit extends Mock implements ChatCubit {}
class MockCallCubit extends Mock implements CallCubit {}
class MockChatLocalDataSource extends Mock implements ChatLocalDataSource {}
