import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:ciro_chat_app/core/error/failures.dart';
import 'package:ciro_chat_app/features/contacts/data/contacts_service.dart';
import 'package:fake_async/fake_async.dart';
import '../../../auth/mocks.dart';
import 'package:ciro_chat_app/features/map/data/datasources/map_location_service.dart';
import 'package:ciro_chat_app/features/map/domain/entities/map_filter.dart';
import 'package:ciro_chat_app/features/map/domain/entities/map_group.dart';
import 'package:ciro_chat_app/features/map/domain/entities/map_user.dart';
import 'package:ciro_chat_app/features/map/domain/repositories/map_repository.dart';
import 'package:ciro_chat_app/features/map/presentation/bloc/map_cubit.dart';
import 'package:ciro_chat_app/features/map/presentation/bloc/map_state.dart';
import 'package:ciro_chat_app/features/map/presentation/utils/marker_icon_factory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockMapRepository extends Mock implements MapRepository {}

class MockMapLocationService extends Mock implements MapLocationService {}

class MockMarkerIconFactory extends Mock implements MarkerIconFactory {}

class MockContactsService extends Mock implements ContactsService {}

MapUser _user(
  String id, {
  bool isOnline = true,
  double lat = 30.0,
  double lng = 31.0,
  DateTime? updatedAt,
  List<String> groupIds = const [],
}) {
  return MapUser(
    id: id,
    name: 'User $id',
    isOnline: isOnline,
    latitude: lat,
    longitude: lng,
    lastUpdatedAt: updatedAt ?? DateTime(2026, 1, 1),
    groupIds: groupIds,
  );
}

Position _position({required double latitude, required double longitude}) {
  return Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: DateTime(2026, 1, 1),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

/// `_init()` runs as fire-and-forget work kicked off from the constructor, so
/// every test must let it settle before asserting state or driving its own
/// action — otherwise the test action races the cubit's own startup load.
const _settleInit = Duration(milliseconds: 20);

void main() {
  late MockMapRepository mockRepository;
  late MockMapLocationService mockLocationService;
  late MockMarkerIconFactory mockIconFactory;
  late MockContactsService mockContactsService;
  late MockAuthLocalDataSource mockAuthLocalDataSource;
  late StreamController<PresenceUpdate> presenceController;
  late StreamController<List<LocationUpdate>> locationController;
  late StreamController<String> hiddenController;
  late StreamController<MapUser> exploreAddedController;

  setUpAll(() {
    registerFallbackValue(_user('fallback'));
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockRepository = MockMapRepository();
    mockLocationService = MockMapLocationService();
    mockIconFactory = MockMarkerIconFactory();
    mockContactsService = MockContactsService();
    mockAuthLocalDataSource = MockAuthLocalDataSource();
    presenceController = StreamController<PresenceUpdate>.broadcast();
    locationController = StreamController<List<LocationUpdate>>.broadcast();
    hiddenController = StreamController<String>.broadcast();
    exploreAddedController = StreamController<MapUser>.broadcast();

    when(() => mockRepository.presenceUpdates).thenAnswer((_) => presenceController.stream);
    when(() => mockRepository.locationUpdates).thenAnswer((_) => locationController.stream);
    when(() => mockRepository.locationHidden).thenAnswer((_) => hiddenController.stream);
    when(() => mockRepository.exploreStatusAdded).thenAnswer((_) => exploreAddedController.stream);
    when(() => mockRepository.getVisibleUsers()).thenAnswer((_) async => const Right([]));
    when(() => mockRepository.getExploreUsers()).thenAnswer((_) async => const Right([]));
    when(() => mockRepository.getGroups()).thenAnswer((_) async => const Right([]));
    when(() => mockRepository.getGhostMode()).thenAnswer((_) async => const Right(false));
    when(() => mockRepository.setGhostMode(any())).thenAnswer((_) async => const Right(true));
    when(() => mockRepository.dispose()).thenReturn(null);
    when(() => mockLocationService.dispose()).thenReturn(null);
    when(() => mockLocationService.stop()).thenAnswer((_) async {});
    when(() => mockLocationService.requestBackgroundPermission())
        .thenAnswer((_) async => true);

    // The icon factory always resolves synchronously to the default marker
    // bitmap and never invokes onResolved, so tests never depend on real
    // widget rasterization or network avatar fetches.
    when(() => mockIconFactory.resolve(
          any(),
          onResolved: any(named: 'onResolved'),
        )).thenAnswer((_) async => BitmapDescriptor.defaultMarker);

    when(() => mockContactsService.getDeviceContactsPhoneToName())
        .thenAnswer((_) async => const {});

    when(() => mockAuthLocalDataSource.getUserId())
        .thenAnswer((_) async => 'current-user');
  });

  tearDown(() {
    presenceController.close();
    locationController.close();
    hiddenController.close();
    exploreAddedController.close();
  });

  MapCubit buildCubit() => MapCubit(
        mockRepository,
        mockLocationService,
        mockIconFactory,
        mockContactsService,
        mockAuthLocalDataSource,
      );

  group('initial load (US1)', () {
    blocTest<MapCubit, MapState>(
      'loadFollowing populates allUsers and markers, transitioning to loaded',
      build: () {
        when(() => mockRepository.getVisibleUsers())
            .thenAnswer((_) async => Right([_user('u1'), _user('u2')]));
        return buildCubit();
      },
      wait: _settleInit,
      verify: (cubit) {
        expect(cubit.state.status, MapViewStatus.loaded);
        expect(cubit.state.allUsers.length, 2);
        expect(cubit.state.googleMarkers.length, 2);
      },
    );

    blocTest<MapCubit, MapState>(
      'loadFollowing with no users transitions to empty',
      build: () => buildCubit(),
      wait: _settleInit,
      verify: (cubit) {
        expect(cubit.state.status, MapViewStatus.empty);
        expect(cubit.state.allUsers, isEmpty);
      },
    );

    blocTest<MapCubit, MapState>(
      'loadFollowing failure surfaces the failure and error status',
      build: () {
        when(() => mockRepository.getVisibleUsers())
            .thenAnswer((_) async => Left(ServerFailure('boom')));
        return buildCubit();
      },
      wait: _settleInit,
      verify: (cubit) {
        expect(cubit.state.status, MapViewStatus.error);
        expect(cubit.state.failure, isA<ServerFailure>());
      },
    );

    blocTest<MapCubit, MapState>(
      'switchTab to explore calls getExploreUsers instead of getVisibleUsers',
      build: () {
        when(() => mockRepository.getExploreUsers())
            .thenAnswer((_) async => Right([_user('e1')]));
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(_settleInit);
        cubit.switchTab(MapTab.explore);
        await Future<void>.delayed(_settleInit);
      },
      verify: (cubit) {
        expect(cubit.state.selectedTab, MapTab.explore);
        expect(cubit.state.allUsers.single.id, 'e1');
        verify(() => mockRepository.getExploreUsers()).called(1);
      },
    );

    blocTest<MapCubit, MapState>(
      'a live locationUpdate while on Explore is ignored entirely, even for '
      "a user who's also in Explore's own dataset (no jump/flicker)",
      build: () {
        when(() => mockRepository.getExploreUsers()).thenAnswer(
          (_) async => Right([_user('e1', lat: 1, lng: 1)]),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(_settleInit);
        cubit.switchTab(MapTab.explore);
        await Future<void>.delayed(_settleInit);
        locationController.add([
          LocationUpdate(
            userId: 'e1',
            longitude: 99,
            latitude: 99,
            isOnline: true,
            lastUpdatedAt: DateTime(2026, 1, 2),
          ),
        ]);
        await Future<void>.delayed(_settleInit);
      },
      verify: (cubit) {
        final e1 = cubit.state.allUsers.firstWhere((u) => u.id == 'e1');
        expect(e1.latitude, 1, reason: 'Explore data must not be mutated by a live ping');
      },
    );
  });

  group('live updates idempotency (FR-022a)', () {
    blocTest<MapCubit, MapState>(
      'a strictly newer location update overwrites the existing position',
      build: () {
        when(() => mockRepository.getVisibleUsers()).thenAnswer(
          (_) async => Right([_user('u1', lat: 1, lng: 1, updatedAt: DateTime(2026, 1, 1))]),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(_settleInit);
        locationController.add([
          LocationUpdate(
            userId: 'u1',
            longitude: 9,
            latitude: 9,
            isOnline: true,
            lastUpdatedAt: DateTime(2026, 1, 2),
          ),
        ]);
        await Future<void>.delayed(_settleInit);
      },
      verify: (cubit) {
        final updated = cubit.state.allUsers.single;
        expect(updated.latitude, 9);
        expect(updated.longitude, 9);
      },
    );

    blocTest<MapCubit, MapState>(
      'a stale (older) location update is ignored — strictly-newer-wins',
      build: () {
        when(() => mockRepository.getVisibleUsers()).thenAnswer(
          (_) async => Right([_user('u1', lat: 1, lng: 1, updatedAt: DateTime(2026, 1, 5))]),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(_settleInit);
        locationController.add([
          LocationUpdate(
            userId: 'u1',
            longitude: 9,
            latitude: 9,
            isOnline: true,
            lastUpdatedAt: DateTime(2026, 1, 1), // older than existing
          ),
        ]);
        await Future<void>.delayed(_settleInit);
      },
      verify: (cubit) {
        final unchanged = cubit.state.allUsers.single;
        expect(unchanged.latitude, 1);
        expect(unchanged.longitude, 1);
      },
    );

    blocTest<MapCubit, MapState>(
      'presence update flips isOnline for an existing authorized user only',
      build: () {
        when(() => mockRepository.getVisibleUsers())
            .thenAnswer((_) async => Right([_user('u1', isOnline: false)]));
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(_settleInit);
        presenceController.add((userId: 'u1', isOnline: true));
        presenceController.add((userId: 'not-authorized', isOnline: true));
        await Future<void>.delayed(_settleInit);
      },
      verify: (cubit) {
        expect(cubit.state.allUsers.single.isOnline, isTrue);
        expect(cubit.state.allUsers.length, 1);
      },
    );

    blocTest<MapCubit, MapState>(
      'a batched locationUpdate array applies each item idempotently (T049): '
      'fresh entries upsert, stale entries are skipped, all in one batch',
      build: () {
        when(() => mockRepository.getVisibleUsers()).thenAnswer(
          (_) async => Right([
            _user('fresh', lat: 1, lng: 1, updatedAt: DateTime(2026, 1, 1)),
            _user('stale', lat: 2, lng: 2, updatedAt: DateTime(2026, 1, 10)),
          ]),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(_settleInit);
        locationController.add([
          LocationUpdate(
            userId: 'fresh',
            longitude: 99,
            latitude: 99,
            isOnline: true,
            lastUpdatedAt: DateTime(2026, 1, 2), // newer than existing
          ),
          LocationUpdate(
            userId: 'stale',
            longitude: 88,
            latitude: 88,
            isOnline: true,
            lastUpdatedAt: DateTime(2026, 1, 5), // older than existing
          ),
          LocationUpdate(
            userId: 'newcomer',
            longitude: 77,
            latitude: 77,
            isOnline: true,
            lastUpdatedAt: DateTime(2026, 1, 1),
          ),
        ]);
        await Future<void>.delayed(_settleInit);
      },
      verify: (cubit) {
        final fresh = cubit.state.allUsers.firstWhere((u) => u.id == 'fresh');
        final stale = cubit.state.allUsers.firstWhere((u) => u.id == 'stale');
        final newcomer = cubit.state.allUsers.firstWhere((u) => u.id == 'newcomer');
        expect(fresh.latitude, 99, reason: 'newer update in the batch must apply');
        expect(stale.latitude, 2, reason: 'older update in the same batch must be ignored');
        expect(newcomer.latitude, 77, reason: 'an unseen user in the batch is added');
      },
    );

    blocTest<MapCubit, MapState>(
      "a locationUpdate echoing the viewer's own id (room broadcast includes "
      "the sender) is ignored, not spliced in as a nameless '?' marker",
      build: () {
        when(() => mockRepository.getVisibleUsers()).thenAnswer(
          (_) async => Right([_user('other', lat: 1, lng: 1)]),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(_settleInit);
        locationController.add([
          LocationUpdate(
            userId: 'current-user', // matches mockAuthLocalDataSource.getUserId()
            longitude: 5,
            latitude: 5,
            isOnline: true,
            lastUpdatedAt: DateTime(2026, 1, 2),
          ),
        ]);
        await Future<void>.delayed(_settleInit);
      },
      verify: (cubit) {
        expect(
          cubit.state.allUsers.any((u) => u.id == 'current-user'),
          isFalse,
          reason: 'the viewer must never appear as a contact in their own allUsers list',
        );
        expect(cubit.state.allUsers.length, 1);
      },
    );

    blocTest<MapCubit, MapState>(
      'locationHidden removes the marker for that user (Ghost Mode by a peer)',
      build: () {
        when(() => mockRepository.getVisibleUsers())
            .thenAnswer((_) async => Right([_user('u1'), _user('u2')]));
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(_settleInit);
        hiddenController.add('u1');
        await Future<void>.delayed(_settleInit);
      },
      verify: (cubit) {
        expect(cubit.state.allUsers.map((u) => u.id), ['u2']);
      },
    );
  });

  group('TTL sweep (T031 / SC-009)', () {
    test('a marker not refreshed within the TTL window is removed on the next sweep tick', () {
      fakeAsync((async) {
        final now = DateTime.now();
        // _sweepStale() compares against the real DateTime.now() (MapCubit
        // doesn't use package:clock), so fakeAsync can only virtualize *when*
        // the periodic Timer ticks — staleness itself must already be true
        // relative to real wall-clock time at construction.
        when(() => mockRepository.getVisibleUsers()).thenAnswer(
          (_) async => Right([
            _user('aging', updatedAt: now.subtract(const Duration(hours: 2, minutes: 1))),
            _user('refreshed', updatedAt: now),
          ]),
        );

        final cubit = buildCubit();
        async.elapse(Duration.zero);
        async.flushMicrotasks();
        expect(cubit.state.allUsers.length, 2);

        // Let one 60s sweep tick fire: 'aging' is already past the TTL,
        // 'refreshed' is not.
        async.elapse(const Duration(seconds: 61));
        async.flushMicrotasks();

        expect(cubit.state.allUsers.map((u) => u.id), ['refreshed']);

        cubit.close();
        async.elapse(Duration.zero);
      });
    });

    test('no sweep occurs before the TTL window elapses', () {
      fakeAsync((async) {
        final startTime = DateTime.now();
        when(() => mockRepository.getVisibleUsers())
            .thenAnswer((_) async => Right([_user('fresh', updatedAt: startTime)]));

        final cubit = buildCubit();
        async.elapse(Duration.zero);
        async.flushMicrotasks();

        // Several sweep ticks fire well within the TTL window — nothing
        // should be removed.
        async.elapse(const Duration(minutes: 30));
        async.flushMicrotasks();

        expect(cubit.state.allUsers.length, 1);

        cubit.close();
        async.elapse(Duration.zero);
      });
    });
  });

  group('filtering (US2)', () {
    blocTest<MapCubit, MapState>(
      'setStatusFilter(online) hides offline users from the marker set',
      build: () {
        when(() => mockRepository.getVisibleUsers()).thenAnswer(
          (_) async => Right([_user('online1', isOnline: true), _user('offline1', isOnline: false)]),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(_settleInit);
        cubit.setStatusFilter(MapStatusFilter.online);
        await Future<void>.delayed(_settleInit);
      },
      verify: (cubit) {
        expect(cubit.state.googleMarkers.length, 1);
        expect(cubit.state.googleMarkers.single.markerId.value, 'online1');
      },
    );

    blocTest<MapCubit, MapState>(
      'setGroupFilter restricts markers to members of that group',
      build: () {
        when(() => mockRepository.getVisibleUsers()).thenAnswer(
          (_) async => Right([
            _user('member', groupIds: ['g1']),
            _user('nonMember', groupIds: ['g2']),
          ]),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(_settleInit);
        cubit.setGroupFilter('g1');
        await Future<void>.delayed(_settleInit);
      },
      verify: (cubit) {
        expect(cubit.state.googleMarkers.single.markerId.value, 'member');
      },
    );

    blocTest<MapCubit, MapState>(
      'status + group filters intersect (T037/SC-007): only an online member of the '
      'selected group survives',
      build: () {
        when(() => mockRepository.getVisibleUsers()).thenAnswer(
          (_) async => Right([
            _user('onlineMember', isOnline: true, groupIds: ['g1']),
            _user('offlineMember', isOnline: false, groupIds: ['g1']),
            _user('onlineNonMember', isOnline: true, groupIds: ['g2']),
            _user('offlineNonMember', isOnline: false, groupIds: ['g2']),
          ]),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(_settleInit);
        cubit.setStatusFilter(MapStatusFilter.online);
        // Each filter setter fires its own unawaited _deriveMarkers(); without
        // letting the first one settle, the two async marker-derivation runs
        // race and whichever emits last (not necessarily the one with both
        // filters applied) wins — settle between them, exactly as the UI does
        // (one filter tap at a time).
        await Future<void>.delayed(_settleInit);
        cubit.setGroupFilter('g1');
        await Future<void>.delayed(_settleInit);
      },
      verify: (cubit) {
        expect(cubit.state.filter.status, MapStatusFilter.online);
        expect(cubit.state.filter.groupId, 'g1');
        expect(cubit.state.googleMarkers.length, 1);
        expect(cubit.state.googleMarkers.single.markerId.value, 'onlineMember');
      },
    );
  });

  group('distance filter (US4)', () {
    blocTest<MapCubit, MapState>(
      'setDistanceFilter(nearby) is inert without a known self location',
      build: () => buildCubit(),
      act: (cubit) async {
        await Future<void>.delayed(_settleInit);
        cubit.setDistanceFilter(MapDistanceFilter.nearby);
        await Future<void>.delayed(_settleInit);
      },
      verify: (cubit) {
        expect(cubit.state.filter.distance, MapDistanceFilter.all);
        verifyNever(() => mockRepository.getNearbyUsers(
              longitude: any(named: 'longitude'),
              latitude: any(named: 'latitude'),
              radiusKm: any(named: 'radiusKm'),
            ));
      },
    );

    blocTest<MapCubit, MapState>(
      'setDistanceFilter(nearby) re-fetches via getNearbyUsers once self location is known (T055)',
      build: () {
        when(() => mockLocationService.requestPermission()).thenAnswer((_) async => true);
        when(() => mockLocationService.getCurrentPosition()).thenAnswer(
          (_) async => _position(latitude: 30.5, longitude: 31.5),
        );
        when(() => mockRepository.getNearbyUsers(
              longitude: any(named: 'longitude'),
              latitude: any(named: 'latitude'),
              radiusKm: any(named: 'radiusKm'),
            )).thenAnswer((_) async => Right([_user('near1')]));
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(_settleInit);
        await cubit.locateMe(); // populates state.selfLocation
        cubit.setDistanceFilter(MapDistanceFilter.nearby);
        await Future<void>.delayed(_settleInit);
      },
      verify: (cubit) {
        expect(cubit.state.filter.distance, MapDistanceFilter.nearby);
        expect(cubit.state.allUsers.single.id, 'near1');
        verify(() => mockRepository.getNearbyUsers(
              longitude: 31.5,
              latitude: 30.5,
              radiusKm: cubit.state.filter.nearbyRadiusKm,
            )).called(1);
      },
    );

    blocTest<MapCubit, MapState>(
      'switching distance filter back to all re-fetches via getVisibleUsers (T055)',
      build: () {
        when(() => mockLocationService.requestPermission()).thenAnswer((_) async => true);
        when(() => mockLocationService.getCurrentPosition()).thenAnswer(
          (_) async => _position(latitude: 30.5, longitude: 31.5),
        );
        when(() => mockRepository.getNearbyUsers(
              longitude: any(named: 'longitude'),
              latitude: any(named: 'latitude'),
              radiusKm: any(named: 'radiusKm'),
            )).thenAnswer((_) async => Right([_user('near1')]));
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(_settleInit);
        await cubit.locateMe();
        cubit.setDistanceFilter(MapDistanceFilter.nearby);
        await Future<void>.delayed(_settleInit);
        cubit.setDistanceFilter(MapDistanceFilter.all);
        await Future<void>.delayed(_settleInit);
      },
      verify: (cubit) {
        expect(cubit.state.filter.distance, MapDistanceFilter.all);
        // Once for the initial _init() load, once for the switch back to "all".
        verify(() => mockRepository.getVisibleUsers()).called(2);
      },
    );
  });

  group('location sharing & Ghost Mode (US3)', () {
    blocTest<MapCubit, MapState>(
      'startSharing requests permission and flips isSharing on success',
      build: () {
        when(() => mockLocationService.requestPermission()).thenAnswer((_) async => true);
        when(() => mockLocationService.getCurrentPosition()).thenAnswer((_) async => null);
        when(() => mockLocationService.start(any())).thenAnswer((_) async {});
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(_settleInit);
        await cubit.startSharing();
      },
      verify: (cubit) {
        expect(cubit.state.isSharing, isTrue);
        expect(cubit.state.permissionGranted, isTrue);
      },
    );

    blocTest<MapCubit, MapState>(
      'a known selfLocation renders as a synthetic "Me" marker, separate from allUsers',
      build: () {
        when(() => mockLocationService.requestPermission()).thenAnswer((_) async => true);
        when(() => mockLocationService.getCurrentPosition()).thenAnswer(
          (_) async => _position(latitude: 30.5, longitude: 31.5),
        );
        when(() => mockLocationService.start(any())).thenAnswer((_) async {});
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(_settleInit);
        await cubit.startSharing();
        await Future<void>.delayed(_settleInit);
      },
      verify: (cubit) {
        final selfMarker = cubit.state.googleMarkers
            .firstWhere((m) => m.markerId.value == 'current-user');
        expect(selfMarker.position.latitude, 30.5);
        expect(selfMarker.position.longitude, 31.5);
        expect(
          cubit.state.allUsers.any((u) => u.id == 'current-user'),
          isFalse,
          reason: 'the self marker is synthesized for display only, never a contact',
        );
      },
    );

    blocTest<MapCubit, MapState>(
      'stopSharing notifies the backend so other viewers stop seeing this marker',
      build: () {
        when(() => mockLocationService.requestPermission()).thenAnswer((_) async => true);
        when(() => mockLocationService.getCurrentPosition()).thenAnswer((_) async => null);
        when(() => mockLocationService.start(any())).thenAnswer((_) async {});
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(_settleInit);
        await cubit.startSharing();
        await cubit.stopSharing();
      },
      verify: (cubit) {
        expect(cubit.state.isSharing, isFalse);
        verify(() => mockRepository.stopSharingLocation()).called(1);
      },
    );

    blocTest<MapCubit, MapState>(
      'startSharing does not start the location stream when permission denied',
      build: () {
        when(() => mockLocationService.requestPermission()).thenAnswer((_) async => false);
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(_settleInit);
        await cubit.startSharing();
      },
      verify: (cubit) {
        expect(cubit.state.isSharing, isFalse);
        expect(cubit.state.permissionGranted, isFalse);
        verifyNever(() => mockLocationService.start(any()));
      },
    );

    blocTest<MapCubit, MapState>(
      'toggleGhostMode optimistically flips isGhostMode then confirms on success',
      build: () => buildCubit(),
      act: (cubit) async {
        await Future<void>.delayed(_settleInit);
        await cubit.toggleGhostMode();
      },
      verify: (cubit) {
        expect(cubit.state.isGhostMode, isTrue);
        verify(() => mockRepository.setGhostMode(true)).called(1);
      },
    );

    blocTest<MapCubit, MapState>(
      'toggleGhostMode reverts the optimistic flip when the backend call fails',
      build: () {
        when(() => mockRepository.setGhostMode(any()))
            .thenAnswer((_) async => Left(ServerFailure('nope')));
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(_settleInit);
        await cubit.toggleGhostMode();
      },
      verify: (cubit) {
        expect(cubit.state.isGhostMode, isFalse);
        expect(cubit.state.failure, isA<ServerFailure>());
      },
    );

    blocTest<MapCubit, MapState>(
      'toggleGhostMode persists the new value to SharedPreferences (T049)',
      build: () => buildCubit(),
      act: (cubit) async {
        await Future<void>.delayed(_settleInit);
        await cubit.toggleGhostMode();
      },
      verify: (cubit) async {
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('map_ghost_mode'), isTrue);
      },
    );

    blocTest<MapCubit, MapState>(
      'a reverted Ghost Mode toggle (backend failure) persists the reverted value too (T049)',
      build: () {
        when(() => mockRepository.setGhostMode(any()))
            .thenAnswer((_) async => Left(ServerFailure('nope')));
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(_settleInit);
        await cubit.toggleGhostMode();
      },
      verify: (cubit) async {
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('map_ghost_mode'), isFalse);
      },
    );

    blocTest<MapCubit, MapState>(
      'enabling Ghost Mode stops active location sharing',
      build: () {
        when(() => mockLocationService.requestPermission()).thenAnswer((_) async => true);
        when(() => mockLocationService.getCurrentPosition()).thenAnswer((_) async => null);
        when(() => mockLocationService.start(any())).thenAnswer((_) async {});
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(_settleInit);
        await cubit.startSharing();
        await cubit.toggleGhostMode();
      },
      verify: (cubit) {
        expect(cubit.state.isSharing, isFalse);
        verify(() => mockLocationService.stop()).called(greaterThanOrEqualTo(1));
      },
    );
  });

  group('map / marker interaction', () {
    blocTest<MapCubit, MapState>(
      'selectUser then selectUser(null) clears selection',
      build: () => buildCubit(),
      act: (cubit) async {
        await Future<void>.delayed(_settleInit);
        cubit.selectUser(_user('u1'));
        cubit.selectUser(null);
      },
      verify: (cubit) => expect(cubit.state.selectedUser, isNull),
    );

    blocTest<MapCubit, MapState>(
      'toggleMapType alternates between normal and satellite',
      build: () => buildCubit(),
      act: (cubit) async {
        await Future<void>.delayed(_settleInit);
        cubit.toggleMapType();
      },
      verify: (cubit) => expect(cubit.state.mapType, MapType.satellite),
    );
  });

  group('groups (US2)', () {
    blocTest<MapCubit, MapState>(
      'loadGroups populates state.groups on success',
      build: () {
        when(() => mockRepository.getGroups()).thenAnswer(
          (_) async => const Right([MapGroup(id: 'g1', name: 'Trip', memberCount: 3, initials: 'T')]),
        );
        return buildCubit();
      },
      wait: _settleInit,
      verify: (cubit) {
        expect(cubit.state.groups.single.id, 'g1');
      },
    );
  });
}
