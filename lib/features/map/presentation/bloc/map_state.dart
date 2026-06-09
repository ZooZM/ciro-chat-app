import 'package:equatable/equatable.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../mock/map_mock_data.dart';

enum MapTab { following, explore }

class MapState extends Equatable {
  const MapState({
    this.selectedTab = MapTab.following,
    this.markers = const [],
    this.googleMarkers = const {},
    this.selectedUser,
    this.mapType = MapType.normal,
  });

  final MapTab selectedTab;
  final List<MockMapMarker> markers;
  final Set<Marker> googleMarkers;
  final MockUser? selectedUser;
  final MapType mapType;

  MapState copyWith({
    MapTab? selectedTab,
    List<MockMapMarker>? markers,
    Set<Marker>? googleMarkers,
    MockUser? selectedUser,
    MapType? mapType,
    bool clearSelectedUser = false,
  }) {
    return MapState(
      selectedTab: selectedTab ?? this.selectedTab,
      markers: markers ?? this.markers,
      googleMarkers: googleMarkers ?? this.googleMarkers,
      selectedUser:
          clearSelectedUser ? null : (selectedUser ?? this.selectedUser),
      mapType: mapType ?? this.mapType,
    );
  }

  @override
  List<Object?> get props => [selectedTab, markers, googleMarkers, selectedUser, mapType];
}
