import 'package:bloc_test/bloc_test.dart';
import 'package:ciro_chat_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_audience_contact.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_content_type.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_privacy.dart';
import 'package:ciro_chat_app/features/status/presentation/bloc/status_creation_cubit.dart';
import 'package:ciro_chat_app/features/status/presentation/bloc/status_creation_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks.dart';
import 'package:ciro_chat_app/features/map/data/datasources/map_location_service.dart';

class MockAuthCubit extends MockCubit<AuthState> implements AuthCubit {}
class MockMapLocationService extends Mock implements MapLocationService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockStatusRepository mockRepository;
  late MockAuthCubit mockAuthCubit;
  late MockMapLocationService mockLocationService;

  const tDefaultAudience = [
    StatusAudienceContact(userId: 'contact-1', name: 'Alice', phoneNumber: '+1', avatarUrl: ''),
    StatusAudienceContact(userId: 'contact-2', name: 'Bob', phoneNumber: '+2', avatarUrl: ''),
  ];

  setUp(() {
    mockRepository = MockStatusRepository();
    mockAuthCubit = MockAuthCubit();
    mockLocationService = MockMapLocationService();
    when(() => mockAuthCubit.state).thenReturn(
      const Authenticated(userData: {'name': 'Me', 'avatarUrl': 'me.png'}),
    );
    when(() => mockAuthCubit.getCurrentUserName())
        .thenAnswer((_) async => 'Me');
  });

  StatusCreationCubit buildCubit() => StatusCreationCubit(
        statusRepository: mockRepository,
        authCubit: mockAuthCubit,
        locationService: mockLocationService,
      );

  group('_updateDraft via copyWith (T053 regression)', () {
    blocTest<StatusCreationCubit, StatusCreationState>(
      'preserves clientStatusId/authorId/audience/syncStatus across draft updates',
      build: buildCubit,
      act: (cubit) async {
        when(() => mockRepository.getDefaultAudience())
            .thenAnswer((_) async => const Right(tDefaultAudience));

        await cubit.initDraft(StatusContentType.text);
        await cubit.updatePrivacy(StatusPrivacy.private); // populates audience
        cubit.updateText('hello world');
        cubit.updateBackgroundColor('#000000');
        cubit.updateFontStyle('serif');
      },
      verify: (cubit) {
        final draft = (cubit.state as StatusCreationComposing).draft;
        expect(draft.privacy, StatusPrivacy.private);
        expect(draft.audience, ['contact-1', 'contact-2']);
        expect(draft.textContent, 'hello world');
        expect(draft.backgroundColor, '#000000');
        expect(draft.fontStyle, 'serif');
        expect(draft.id, isNotEmpty);
        expect(draft.syncStatus, 'synced'); // default, never silently reset to ''
      },
    );
  });

  group('updatePrivacy (T053)', () {
    blocTest<StatusCreationCubit, StatusCreationState>(
      'pre-selects the default audience when switching to private with no audience set',
      build: buildCubit,
      act: (cubit) async {
        when(() => mockRepository.getDefaultAudience())
            .thenAnswer((_) async => const Right(tDefaultAudience));

        await cubit.initDraft(StatusContentType.text);
        await cubit.updatePrivacy(StatusPrivacy.private);
      },
      verify: (cubit) {
        final draft = (cubit.state as StatusCreationComposing).draft;
        expect(draft.audience, ['contact-1', 'contact-2']);
        verify(() => mockRepository.getDefaultAudience()).called(1);
      },
    );

    blocTest<StatusCreationCubit, StatusCreationState>(
      'does not overwrite an already-populated audience',
      build: buildCubit,
      act: (cubit) async {
        when(() => mockRepository.getDefaultAudience())
            .thenAnswer((_) async => const Right(tDefaultAudience));

        await cubit.initDraft(StatusContentType.text);
        await cubit.updatePrivacy(StatusPrivacy.private);
        await cubit.updatePrivacy(StatusPrivacy.private);
      },
      verify: (cubit) {
        verify(() => mockRepository.getDefaultAudience()).called(1);
      },
    );

    blocTest<StatusCreationCubit, StatusCreationState>(
      'does not fetch default audience for non-private privacy levels',
      build: buildCubit,
      act: (cubit) async {
        await cubit.initDraft(StatusContentType.text);
        await cubit.updatePrivacy(StatusPrivacy.public);
        await cubit.updatePrivacy(StatusPrivacy.showOnMap);
      },
      verify: (cubit) {
        verifyNever(() => mockRepository.getDefaultAudience());
      },
    );
  });
}
