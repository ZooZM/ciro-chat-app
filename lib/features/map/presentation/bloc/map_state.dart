import 'package:equatable/equatable.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ciro_chat_app/core/error/failures.dart';
import '../../domain/entities/map_user.dart';
import '../../domain/entities/map_filter.dart';
import '../../domain/entities/map_group.dart';

enum MapTab { following, explore }

enum MapViewStatus { loading, loaded, empty, error }

class MapState extends Equatable {
  const MapState({
    this.status = MapViewStatus.loading,
    this.selectedTab = MapTab.following,
    this.allUsers = const [],
    this.filter = const MapFilter(),
    this.groups = const [],
    this.googleMarkers = const {},
    this.selectedUser,
    this.mapType = MapType.normal,
    this.selfLocation,
    this.isSharing = false,
    this.isGhostMode = false,
    this.permissionGranted = false,
    this.failure,
  });

  final MapViewStatus status;
  final MapTab selectedTab;

  /// The authorized set from the backend, mutated by live events. Filters
  /// are derived from this list, never mutate it destructively (FR-022a).
  final List<MapUser> allUsers;
  final MapFilter filter;
  final List<MapGroup> groups;
  final Set<Marker> googleMarkers;
  final MapUser? selectedUser;
  final MapType mapType;
  final LatLng? selfLocation;
  final bool isSharing;
  final bool isGhostMode;
  final bool permissionGranted;
  final Failure? failure;

  MapState copyWith({
    MapViewStatus? status,
    MapTab? selectedTab,
    List<MapUser>? allUsers,
    MapFilter? filter,
    List<MapGroup>? groups,
    Set<Marker>? googleMarkers,
    MapUser? selectedUser,
    bool clearSelectedUser = false,
    MapType? mapType,
    LatLng? selfLocation,
    bool? isSharing,
    bool? isGhostMode,
    bool? permissionGranted,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return MapState(
      status: status ?? this.status,
      selectedTab: selectedTab ?? this.selectedTab,
      allUsers: allUsers ?? this.allUsers,
      filter: filter ?? this.filter,
      groups: groups ?? this.groups,
      googleMarkers: googleMarkers ?? this.googleMarkers,
      selectedUser: clearSelectedUser ? null : (selectedUser ?? this.selectedUser),
      mapType: mapType ?? this.mapType,
      selfLocation: selfLocation ?? this.selfLocation,
      isSharing: isSharing ?? this.isSharing,
      isGhostMode: isGhostMode ?? this.isGhostMode,
      permissionGranted: permissionGranted ?? this.permissionGranted,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [
    status,
    selectedTab,
    allUsers,
    filter,
    groups,
    googleMarkers,
    selectedUser,
    mapType,
    selfLocation,
    isSharing,
    isGhostMode,
    permissionGranted,
    failure,
  ];
}
