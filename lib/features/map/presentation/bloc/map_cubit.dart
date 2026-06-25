import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../auth/data/datasources/auth_local_data_source.dart';
import '../../../contacts/data/contacts_service.dart';
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
  MapCubit(
    this._repository,
    this._locationService,
    this._iconFactory,
    this._contactsService,
    this._authLocalDataSource,
  ) : super(const MapState()) {
    _init();
  }

  final MapRepository _repository;
  final MapLocationService _locationService;
  final MarkerIconFactory _iconFactory;
  final ContactsService _contactsService;
  final AuthLocalDataSource _authLocalDataSource;

  /// Device contacts' phone→name lookup (FR: contact name takes priority
  /// over the backend-stored name when the number is saved locally).
  /// Best-effort: empty until loaded, and stays empty if contacts permission
  /// was never granted — callers fall back to the DB name either way.
  Map<String, String> _phoneToName = const {};

  /// The viewer's own id. The backend's batched `locationUpdate` socket
  /// event is broadcast per-room (not per-recipient), so a viewer who is
  /// also sharing receives their own ping echoed back — without this,
  /// `_onLocationUpdate` would mistake that for a brand-new contact and
  /// splice in a nameless "?" marker for themselves.
  String _currentUserId = '';

  StreamSubscription<PresenceUpdate>? _presenceSub;
  StreamSubscription<List<LocationUpdate>>? _locationSub;
  StreamSubscription<String>? _hiddenSub;
  StreamSubscription<MapUser>? _exploreAddedSub;
  Timer? _ttlTimer;

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    emit(state.copyWith(isGhostMode: prefs.getBool(_kGhostModePrefsKey) ?? false));
    _currentUserId = await _authLocalDataSource.getUserId() ?? '';

    _presenceSub = _repository.presenceUpdates.listen(_onPresenceUpdate);
    _locationSub = _repository.locationUpdates.listen(_onLocationUpdate);
    _hiddenSub = _repository.locationHidden.listen(_onLocationHidden);
    _exploreAddedSub =
        _repository.exploreStatusAdded.listen(_onExploreStatusAdded);
    _ttlTimer = Timer.periodic(_kTtlSweepInterval, (_) => _sweepStale());

    unawaited(_loadContactNames());
    await loadFollowing();
    await loadGroups();
    unawaited(_hydrateGhostMode());
  }

  /// Loads the device contacts phone→name map (non-blocking relative to the
  /// initial fetch above) and, once available, retroactively relabels
  /// whatever's already in `allUsers` so contact names apply even if this
  /// resolves after the first render.
  Future<void> _loadContactNames() async {
    try {
      _phoneToName = await _contactsService.getDeviceContactsPhoneToName();
    } catch (_) {
      _phoneToName = const {};
    }
    if (isClosed || _phoneToName.isEmpty) return;
    final relabeled = state.allUsers.map((u) => u.copyWith(name: _resolveDisplayName(u))).toList();
    emit(state.copyWith(allUsers: relabeled));
    unawaited(_deriveMarkers());
  }

  /// Contact name (if the user's number is saved on this device) takes
  /// priority over the backend-stored display name; otherwise falls back to
  /// the DB name (FR: never show a "?" placeholder once a name is known).
  String _resolveDisplayName(MapUser user) {
    final phone = user.phoneNumber;
    if (phone == null || phone.isEmpty) return user.name;
    final contactName = _phoneToName[phone];
    return (contactName != null && contactName.isNotEmpty) ? contactName : user.name;
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
    final resolved = users.map((u) => u.copyWith(name: _resolveDisplayName(u))).toList();
    emit(state.copyWith(allUsers: resolved));
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
    // Live location pings are Following-tab data (FR-006/006a). Explore's
    // membership is a different, status-based set entirely (FR-001a/b) —
    // applying a live ping to an existing Explore entry would fight its own
    // REST-derived (possibly coarsened) position, making the marker jump or
    // flicker. Bail out entirely rather than gate per-item: with `allUsers`
    // wholesale-replaced on every tab switch, this handler only ever has
    // Following-tab work to do when Following is the active tab.
    if (state.selectedTab != MapTab.following) return;
    var users = List<MapUser>.from(state.allUsers);
    var changed = false;
    var hasNewUser = false;
    for (final update in updates) {
      // The room-broadcast echoes our own ping back to us — never treat our
      // own id as a contact (see _currentUserId doc comment above).
      if (update.userId == _currentUserId) continue;
      final index = users.indexWhere((u) => u.id == update.userId);
      if (index == -1) {
        // New authorized contact starting to share — add it. The socket
        // payload has no name/avatar/phone (FR-006a batching keeps it
        // minimal), so this starts blank and gets backfilled below.
        users.add(MapUser(
          id: update.userId,
          name: '',
          isOnline: update.isOnline,
          latitude: update.latitude,
          longitude: update.longitude,
          lastUpdatedAt: update.lastUpdatedAt,
        ));
        changed = true;
        hasNewUser = true;
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
    if (hasNewUser) unawaited(_enrichPendingNames());
  }

  /// Backfills name/avatar/phoneNumber for the bare placeholders
  /// [_onLocationUpdate] inserts for brand-new socket-only contacts. Unlike
  /// `loadFollowing()`/`_applyUsers()`, this is a non-destructive merge: it
  /// only fills in still-blank names and never removes or regresses an
  /// existing entry's position/timestamp, so it can't race with — or
  /// undo — a fresher concurrent live update (SC-011).
  Future<void> _enrichPendingNames() async {
    final result = await _repository.getVisibleUsers();
    result.fold((_) {}, (fetched) {
      if (isClosed) return;
      final byId = {for (final u in fetched) u.id: u};
      var changed = false;
      final merged = state.allUsers.map((existing) {
        if (existing.name.isNotEmpty) return existing;
        final fromRest = byId[existing.id];
        if (fromRest == null) return existing;
        changed = true;
        return existing.copyWith(
          name: _resolveDisplayName(fromRest),
          phoneNumber: fromRest.phoneNumber,
          avatarUrl: fromRest.avatarUrl,
        );
      }).toList();
      if (!changed) return;
      emit(state.copyWith(allUsers: merged));
      unawaited(_deriveMarkers());
    });
  }

  void _onLocationHidden(String userId) {
    // Same Following-only scoping as _onLocationUpdate — stopping live
    // sharing (or Ghost Mode) has nothing to do with Explore's status-based
    // membership, so it must not remove someone from Explore's dataset.
    if (state.selectedTab != MapTab.following) return;
    if (!state.allUsers.any((u) => u.id == userId)) return;
    final updated = state.allUsers.where((u) => u.id != userId).toList();
    emit(state.copyWith(allUsers: updated));
    unawaited(_deriveMarkers());
  }

  /// A new "Show on Map" status was posted live (018-snap-map-realtime) —
  /// only relevant to whoever is currently looking at Explore (a different,
  /// status-based dataset from Following's, same scoping rationale as
  /// _onLocationUpdate/_onLocationHidden above). The broadcast always carries
  /// coarse coordinates (a single server-wide emit can't apply per-viewer
  /// coarsening); if this viewer turns out to be a contact, the next full
  /// Explore reload backfills the precise position.
  void _onExploreStatusAdded(MapUser user) {
    if (state.selectedTab != MapTab.explore) return;
    if (user.id == _currentUserId) return;
    final resolved = user.copyWith(name: _resolveDisplayName(user));
    final index = state.allUsers.indexWhere((u) => u.id == user.id);
    final updated = List<MapUser>.from(state.allUsers);
    if (index == -1) {
      updated.add(resolved);
    } else {
      updated[index] = resolved;
    }
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

    // Best-effort escalation to background ("Always") permission so sharing
    // survives the app being backgrounded. Awaited (not fire-and-forget) so
    // the foreground-service/background-updates config below sees the final
    // permission state. If denied, sharing still starts and works fine in
    // the foreground — it just won't continue once backgrounded.
    await _locationService.requestBackgroundPermission();

    final position = await _locationService.getCurrentPosition();
    if (position != null) {
      emit(state.copyWith(
        selfLocation: LatLng(position.latitude, position.longitude),
      ));
      unawaited(_deriveMarkers());
    }

    await _locationService.start((longitude, latitude) {
      _repository.shareLocation(longitude: longitude, latitude: latitude);
      if (!isClosed) {
        emit(state.copyWith(selfLocation: LatLng(latitude, longitude)));
        unawaited(_deriveMarkers());
      }
    });
    emit(state.copyWith(isSharing: true));
  }

  Future<void> stopSharing() async {
    await _stopLocalSharing();
    _repository.stopSharingLocation();
  }

  /// Just the local geolocator stream + UI flag — distinct from
  /// [stopSharing] itself, which additionally tells the backend the user
  /// stopped sharing (excluding them from Following-tab queries). Ghost
  /// Mode needs only the former: it already has its own complete,
  /// independent visibility mechanism (`isGhostMode` + its own
  /// locationHidden/locationUpdate re-broadcast on toggle), so routing it
  /// through the backend "stopped sharing" signal too would desync —
  /// turning Ghost Mode back off wouldn't restore Following-tab visibility.
  Future<void> _stopLocalSharing() async {
    await _locationService.stop();
    emit(state.copyWith(isSharing: false));
  }

  Future<void> pauseSharingForBackground() => _locationService.stop();

  Future<void> resumeSharingForForeground() async {
    if (state.isSharing) await _locationService.resume();
  }

  /// Fetches the device's current position and centers `state.selfLocation`
  /// on it. By default a no-op once a location is already known (e.g. called
  /// automatically when the map first loads); pass [force] to always re-fetch
  /// and re-center, as when the user explicitly taps the Locate Me FAB.
  Future<void> locateMe({bool force = false}) async {
    if (state.selfLocation != null && !force) return;
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
      unawaited(_deriveMarkers());
    }
  }

  /// Clears per-account map state on logout (Constitution IV-B/V: this
  /// lazySingleton must not leak one user's contacts/location to the next
  /// login on a shared device). Live socket/location-update subscriptions are
  /// left intact — they simply receive nothing until the next session
  /// reconnects.
  Future<void> reset() async {
    if (state.isSharing) await _locationService.stop();
    emit(const MapState());
  }

  /// Re-populates this lazySingleton's map data for a freshly logged-in
  /// account. Mirrors `ChatCubit.silentSyncContacts()` — called by AuthCubit
  /// right after a successful login/app-start auth check.
  Future<void> refreshSession() async {
    unawaited(_hydrateGhostMode());
    await loadFollowing();
    await loadGroups();
  }

  Future<void> toggleGhostMode() async {
    final enabling = !state.isGhostMode;
    final prefs = await SharedPreferences.getInstance();
    emit(state.copyWith(isGhostMode: enabling));
    await prefs.setBool(_kGhostModePrefsKey, enabling);
    if (enabling) await _stopLocalSharing();

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
    // The viewer's own marker — never part of `allUsers` (self is excluded
    // both by the backend's authorized-set queries and by the socket-echo
    // guard in `_onLocationUpdate`), so it's synthesized straight from
    // `selfLocation` instead. Unfiltered by status/group — it's not a
    // contact, just a personal position reference.
    final selfLocation = state.selfLocation;
    if (selfLocation != null) {
      final self = MapUser(
        id: _currentUserId.isNotEmpty ? _currentUserId : '__self__',
        // The displayed label always comes from `isCurrentUser` in
        // MapAvatarMarker (translated there); this is just the fallback
        // initial-letter source if no avatar is resolved.
        name: 'Me',
        isOnline: true,
        latitude: selfLocation.latitude,
        longitude: selfLocation.longitude,
        lastUpdatedAt: DateTime.now(),
        isCurrentUser: true,
      );
      final icon = await _iconFactory.resolve(
        self,
        onResolved: (icon) => _onIconResolved(self.id, icon),
      );
      markers.add(_buildMarker(self, icon));
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
    _exploreAddedSub?.cancel();
    _ttlTimer?.cancel();
    _locationService.dispose();
    _repository.dispose();
    return super.close();
  }
}
