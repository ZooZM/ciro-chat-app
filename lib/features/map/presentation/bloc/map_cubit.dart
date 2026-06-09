import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../mock/map_mock_data.dart';
import '../widgets/map_avatar_marker.dart';
import 'package:widget_to_marker/widget_to_marker.dart';
import 'map_state.dart';

class MapCubit extends Cubit<MapState> {
  MapCubit()
      : super(MapState(
          selectedTab: MapTab.following,
          markers: mockMapMarkers,
        )) {
    _loadGoogleMarkers();
  }

  Future<void> _loadGoogleMarkers() async {
    final Set<Marker> googleMarkers = {};
    for (final marker in mockMapMarkers) {
      final icon = await MapAvatarMarker(marker: marker).toBitmapDescriptor();
      googleMarkers.add(
        Marker(
          markerId: MarkerId(marker.user.id),
          position: LatLng(marker.latitude, marker.longitude),
          icon: icon,
          onTap: () {
            selectUser(marker.user);
          },
        ),
      );
    }
    if (!isClosed) {
      emit(state.copyWith(googleMarkers: googleMarkers));
    }
  }

  void switchTab(MapTab tab) {
    emit(state.copyWith(selectedTab: tab));
  }

  void selectUser(MockUser? user) {
    emit(state.copyWith(
      selectedUser: user,
      clearSelectedUser: user == null,
    ));
  }

  void toggleMapType() {
    final newType = state.mapType == MapType.normal
        ? MapType.satellite
        : MapType.normal;
    emit(state.copyWith(mapType: newType));
  }
}
