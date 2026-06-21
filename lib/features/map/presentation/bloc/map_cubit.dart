import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/datasources/map_location_service.dart';
import '../../domain/entities/map_filter.dart';
import '../../domain/entities/map_user.dart';
import '../../domain/repositories/map_repository.dart';
import '../utils/marker_icon_factory.dart';
import 'map_state.dart';

const _kGhostModePrefsKey = 'map_ghost_mode';

/// TTL window for ghost-marker cleanup (FR-003c / SC-009, R11). Distinct from
/// the backend's 24h "nearby" staleness window (R5) — this is purely about
/// hiding markers the client hasn't heard about in a while.
const _kMarkerTtl = Duration(hours: 2);
const _kTtlSweepInterval = Duration(seconds: 60);

// `@lazySingleton` (not the usual `@injectable` factory) because main.dart's
// app-lifecycle observer must reach this exact instance via `getIt<MapCubit>()`
// to pause/resume location sharing on background/foreground (FR-031) — a
// factory registration would hand back an unrelated, disconnected instance.
@lazySingleton
class MapCubit extends Cubit<MapState> {
  MapCubit(this._repository, this._locationService, this._iconFactory)
      : super(const MapState()) {
    _init();
  }

  final MapRepository _repository;
  final MapLocationService _locationService;
  final MarkerIconFactory _iconFactory;

  StreamSubscription<PresenceUpdate>? _presenceSub;
  StreamSubscription<List<LocationUpdate>>? _locationSub;
  StreamSubscription<String>? _hiddenSub;
  Timer? _ttlTimer;

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    emit(state.copyWith(isGhostMode: prefs.getBool(_kGhostModePrefsKey) ?? false));

    _presenceSub = _repository.presenceUpdates.listen(_onPresenceUpdate);
    _locationSub = _repository.locationUpdates.listen(_onLocationUpdate);
    _hiddenSub = _repository.locationHidden.listen(_onLocationHidden);
    _ttlTimer = Timer.periodic(_kTtlSweepInterval, (_) => _sweepStale());

    await loadFollowing();
    await loadGroups();
    unawaited(_hydrateGhostMode());
  }

  Future<void> _hydrateGhostMode() async {
    final result = await _repository.getGhostMode();
    result.fold(
      (_) {},
      (isGhost) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_kGhostModePrefsKey, isGhost);
        if (!isClosed) emit(state.copyWith(isGhostMode: isGhost));
      },
    );
  }

  // ── Loading (US1) ─────────────────────────────────────────────────────────

  Future<void> loadFollowing() async {
    emit(state.copyWith(status: MapViewStatus.loading, clearFailure: true));
    final result = state.filter.distance == MapDistanceFilter.nearby &&
            state.selfLocation != null
        ? await _repository.getNearbyUsers(
            longitude: state.selfLocation!.longitude,
            latitude: state.selfLocation!.latitude,
            radiusKm: state.filter.nearbyRadiusKm,
          )
        : await _repository.getVisibleUsers();

    result.fold(
      (failure) => emit(state.copyWith(status: MapViewStatus.error, failure: failure)),
      (users) => _applyUsers(users),
    );
  }

  Future<void> loadExplore() async {
    emit(state.copyWith(status: MapViewStatus.loading, clearFailure: true));
    final result = await _repository.getExploreUsers();
    result.fold(
      (failure) => emit(state.copyWith(status: MapViewStatus.error, failure: failure)),
      (users) => _applyUsers(users),
    );
  }

  void switchTab(MapTab tab) {
    if (tab == state.selectedTab) return;
    emit(state.copyWith(selectedTab: tab));
    if (tab == MapTab.explore) {
      unawaited(loadExplore());
    } else {
      unawaited(loadFollowing());
    }
  }

  Future<void> retry() => state.selectedTab == MapTab.explore ? loadExplore() : loadFollowing();

  void _applyUsers(List<MapUser> users) {
    emit(state.copyWith(allUsers: users));
    unawaited(_deriveMarkers());
  }

  Future<void> loadGroups() async {
    final result = await _repository.getGroups();
    result.fold((_) {}, (groups) {
      if (!isClosed) emit(state.copyWith(groups: groups));
    });
  }

  // ── Live updates: idempotent upsert (FR-022a / SC-011) ──────────────────

  void _onPresenceUpdate(PresenceUpdate update) {
    final index = state.allUsers.indexWhere((u) => u.id == update.userId);
    if (index == -1) return; // not an authorized/visible contact
    final updated = List<MapUser>.from(state.allUsers);
    updated[index] = updated[index].copyWith(isOnline: update.isOnline);
    emit(state.copyWith(allUsers: updated));
    unawaited(_deriveMarkers());
  }

  void _onLocationUpdate(List<LocationUpdate> updates) {
    var users = List<MapUser>.from(state.allUsers);
    var changed = false;
    for (final update in updates) {
      final index = users.indexWhere((u) => u.id == update.userId);
      if (index == -1) {
        // New authorized contact starting to share — add it.
        users.add(MapUser(
          id: update.userId,
          name: '',
          isOnline: update.isOnline,
          latitude: update.latitude,
          longitude: update.longitude,
          lastUpdatedAt: update.lastUpdatedAt,
        ));
        changed = true;
        continue;
      }
      final existing = users[index];
      // Strictly-newer-wins: never let a stale frame regress fresher state.
      if (!update.lastUpdatedAt.isAfter(existing.lastUpdatedAt)) continue;
      users[index] = existing.copyWith(
        latitude: update.latitude,
        longitude: update.longitude,
        isOnline: update.isOnline,
        lastUpdatedAt: update.lastUpdatedAt,
      );
      changed = true;
    }
    if (!changed) return;
    emit(state.copyWith(allUsers: users));
    unawaited(_deriveMarkers());
  }

  void _onLocationHidden(String userId) {
    if (!state.allUsers.any((u) => u.id == userId)) return;
    final updated = state.allUsers.where((u) => u.id != userId).toList();
    emit(state.copyWith(allUsers: updated));
    unawaited(_deriveMarkers());
  }

  void _sweepStale() {
    final now = DateTime.now();
    final fresh = state.allUsers
        .where((u) => now.difference(u.lastUpdatedAt) <= _kMarkerTtl)
        .toList();
    if (fresh.length == state.allUsers.length) return;
    emit(state.copyWith(allUsers: fresh));
    unawaited(_deriveMarkers());
  }

  // ── Filtering (US2) ───────────────────────────────────────────────────────

  void setStatusFilter(MapStatusFilter status) {
    emit(state.copyWith(filter: state.filter.copyWith(status: status)));
    unawaited(_deriveMarkers());
  }

  void setGroupFilter(String? groupId) {
    emit(state.copyWith(
      filter: groupId == null
          ? state.filter.copyWith(clearGroupId: true)
          : state.filter.copyWith(groupId: groupId),
    ));
    unawaited(_deriveMarkers());
  }

  // ── Distance (US4) ────────────────────────────────────────────────────────

  void setDistanceFilter(MapDistanceFilter distance) {
    if (distance == MapDistanceFilter.nearby && state.selfLocation == null) {
      return; // inert without a known self location (FR-018 edge case)
    }
    emit(state.copyWith(filter: state.filter.copyWith(distance: distance)));
    unawaited(loadFollowing());
  }

  // ── Location sharing & Ghost Mode (US3) ──────────────────────────────────

  Future<void> startSharing() async {
    final granted = await _locationService.requestPermission();
    emit(state.copyWith(permissionGranted: granted));
    if (!granted) return;

    final position = await _locationService.getCurrentPosition();
    if (position != null) {
      emit(state.copyWith(
        selfLocation: LatLng(position.latitude, position.longitude),
      ));
    }

    await _locationService.start((longitude, latitude) {
      _repository.shareLocation(longitude: longitude, latitude: latitude);
      if (!isClosed) {
        emit(state.copyWith(selfLocation: LatLng(latitude, longitude)));
      }
    });
    emit(state.copyWith(isSharing: true));
  }

  Future<void> stopSharing() async {
    await _locationService.stop();
    emit(state.copyWith(isSharing: false));
  }

  Future<void> pauseSharingForBackground() => _locationService.stop();

  Future<void> resumeSharingForForeground() async {
    if (state.isSharing) await _locationService.resume();
  }

  Future<void> locateMe() async {
    if (state.selfLocation != null) return;
    final granted = await _locationService.requestPermission();
    if (!granted) {
      emit(state.copyWith(permissionGranted: false));
      return;
    }
    final position = await _locationService.getCurrentPosition();
    if (position != null) {
      emit(state.copyWith(
        permissionGranted: true,
        selfLocation: LatLng(position.latitude, position.longitude),
      ));
    }
  }

  Future<void> toggleGhostMode() async {
    final enabling = !state.isGhostMode;
    final prefs = await SharedPreferences.getInstance();
    emit(state.copyWith(isGhostMode: enabling));
    await prefs.setBool(_kGhostModePrefsKey, enabling);
    if (enabling) await stopSharing();

    final result = await _repository.setGhostMode(enabling);
    result.fold((failure) {
      // Revert optimistic flip on failure (Constitution VII: friendly state, no crash).
      if (!isClosed) emit(state.copyWith(isGhostMode: !enabling, failure: failure));
      prefs.setBool(_kGhostModePrefsKey, !enabling);
    }, (_) {});
  }

  // ── Map / marker interaction ─────────────────────────────────────────────

  void selectUser(MapUser? user) {
    emit(state.copyWith(selectedUser: user, clearSelectedUser: user == null));
  }

  void toggleMapType() {
    final newType =
        state.mapType == MapType.normal ? MapType.satellite : MapType.normal;
    emit(state.copyWith(mapType: newType));
  }

  // ── Marker derivation (filter + icon resolution; clustering added in US5) ─

  Future<void> _deriveMarkers() async {
    final visible = state.allUsers.where(state.filter.matches).toList();
    final markers = <Marker>{};
    for (final user in visible) {
      final icon = await _iconFactory.resolve(
        user,
        onResolved: (icon) => _onIconResolved(user.id, icon),
      );
      markers.add(_buildMarker(user, icon));
    }
    if (!isClosed) {
      emit(state.copyWith(
        googleMarkers: markers,
        status: visible.isEmpty ? MapViewStatus.empty : MapViewStatus.loaded,
      ));
    }
  }

  Marker _buildMarker(MapUser user, BitmapDescriptor icon) => Marker(
        markerId: MarkerId(user.id),
        position: LatLng(user.latitude, user.longitude),
        icon: icon,
        onTap: () => selectUser(user),
      );

  /// Patches a single marker's icon once the off-thread composite finishes
  /// (FR-027), instead of re-deriving the whole marker set and risking
  /// flicker/jank for every other marker already on screen.
  void _onIconResolved(String userId, BitmapDescriptor icon) {
    if (isClosed) return;
    final updated = state.googleMarkers.map((m) {
      if (m.markerId.value != userId) return m;
      return m.copyWith(iconParam: icon);
    }).toSet();
    emit(state.copyWith(googleMarkers: updated));
  }

  @override
  Future<void> close() {
    _presenceSub?.cancel();
    _locationSub?.cancel();
    _hiddenSub?.cancel();
    _ttlTimer?.cancel();
    _locationService.dispose();
    _repository.dispose();
    return super.close();
  }
}
