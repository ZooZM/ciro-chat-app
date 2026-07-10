import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:ciro_chat_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:ciro_chat_app/core/error/failures.dart';
import 'package:ciro_chat_app/core/di/injection.dart';
import 'package:ciro_chat_app/core/network/socket_service.dart';
import 'package:ciro_chat_app/features/chat/presentation/bloc/chat_cubit.dart';
import 'package:ciro_chat_app/features/video_call/presentation/bloc/call_cubit.dart';
import 'package:ciro_chat_app/features/chat/data/datasources/chat_local_data_source.dart';

import '../../mocks.dart';

void main() {
  late AuthCubit cubit;
  late MockAuthRepository mockRepository;
  late MockAuthLocalDataSource mockLocalDataSource;
  late MockSocketService mockSocketService;
  late MockChatCubit mockChatCubit;
  late MockCallCubit mockCallCubit;
  late MockChatLocalDataSource mockChatLocalDataSource;

  setUpAll(() {
    mockSocketService = MockSocketService();
    mockChatCubit = MockChatCubit();
    mockCallCubit = MockCallCubit();
    mockChatLocalDataSource = MockChatLocalDataSource();

    getIt.registerSingleton<SocketService>(mockSocketService);
    getIt.registerSingleton<ChatCubit>(mockChatCubit);
    getIt.registerSingleton<CallCubit>(mockCallCubit);
    getIt.registerSingleton<ChatLocalDataSource>(mockChatLocalDataSource);
  });

  setUp(() {
    mockRepository = MockAuthRepository();
    mockLocalDataSource = MockAuthLocalDataSource();
    cubit = AuthCubit(mockRepository, mockLocalDataSource);

    // Reset interactions on singletons registered in getIt
    clearInteractions(mockSocketService);
    clearInteractions(mockChatCubit);
    clearInteractions(mockCallCubit);
    clearInteractions(mockChatLocalDataSource);

    // Default setups
    when(() => mockSocketService.connect(any())).thenReturn(null);
    when(() => mockSocketService.disconnect()).thenReturn(null);
    when(() => mockChatCubit.silentSyncContacts()).thenAnswer((_) async => true);
    when(() => mockChatCubit.reset()).thenReturn(null);
    when(() => mockCallCubit.reset()).thenAnswer((_) async {});
    when(() => mockChatLocalDataSource.clearAllData()).thenAnswer((_) async => {});
  });

  tearDown(() {
    cubit.close();
  });

  group('verifyAuthStatus', () {
    test('should emit [AuthLoading, Authenticated] when repository returns true', () async {
      // arrange
      when(() => mockRepository.checkAuthStatus()).thenAnswer((_) async => const Right(true));
      when(() => mockLocalDataSource.getAccessToken()).thenAnswer((_) async => 'token');

      // assert later
      final expected = [
        const AuthLoading(),
        const Authenticated(),
      ];
      expectLater(cubit.stream, emitsInOrder(expected));

      // act
      await cubit.verifyAuthStatus();
      
      verify(() => mockSocketService.connect('token')).called(1);
    });

    test('should emit [AuthLoading, Unauthenticated] when repository returns false', () async {
      // arrange
      when(() => mockRepository.checkAuthStatus()).thenAnswer((_) async => const Right(false));

      // assert later
      final expected = [
        const AuthLoading(),
        const Unauthenticated(),
      ];
      expectLater(cubit.stream, emitsInOrder(expected));

      // act
      await cubit.verifyAuthStatus();
      
      verify(() => mockSocketService.disconnect()).called(1);
    });
  });

  group('submitPhoneNumber', () {
    const tPhone = '1234567890';

    blocTest<AuthCubit, AuthState>(
      'emits [AuthLoading, Unauthenticated] when success',
      build: () {
        when(() => mockRepository.sendOtp(any())).thenAnswer((_) async => const Right(null));
        return cubit;
      },
      act: (cubit) => cubit.submitPhoneNumber(tPhone),
      expect: () => [
        const AuthLoading(),
        const Unauthenticated(),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'emits [AuthLoading, AuthError] when failure',
      build: () {
        when(() => mockRepository.sendOtp(any())).thenAnswer((_) async => Left(ServerFailure('Error')));
        return cubit;
      },
      act: (cubit) => cubit.submitPhoneNumber(tPhone),
      expect: () => [
        const AuthLoading(),
        AuthError(ServerFailure('Error')),
      ],
    );
  });

  group('submitOtp', () {
    const tPhone = '1234567890';
    const tCode = '1234';
    final tResponse = {'user': 'u123'};

    blocTest<AuthCubit, AuthState>(
      'emits [AuthLoading, Authenticated] when success',
      build: () {
        when(() => mockRepository.verifyOtp(any(), any())).thenAnswer((_) async => Right(tResponse));
        when(() => mockLocalDataSource.getAccessToken()).thenAnswer((_) async => 'token');
        return cubit;
      },
      act: (cubit) => cubit.submitOtp(tPhone, tCode),
      expect: () => [
        const AuthLoading(),
        Authenticated(userData: tResponse),
      ],
    );
  });

  group('logOut', () {
    test('should perform all teardown steps and emit Unauthenticated', () async {
      // arrange
      when(() => mockRepository.logout()).thenAnswer((_) async => const Right(null));

      // assert later
      final expected = [
        const AuthLoading(),
        const Unauthenticated(),
      ];
      expectLater(cubit.stream, emitsInOrder(expected));

      // act
      await cubit.logOut();

      // assert
      verify(() => mockChatCubit.reset()).called(1);
      verify(() => mockCallCubit.reset()).called(1);
      verify(() => mockSocketService.disconnect()).called(1);
      verify(() => mockChatLocalDataSource.clearAllData()).called(1);
      verify(() => mockRepository.logout()).called(1);
    });
  });
}
