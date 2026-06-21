import 'package:equatable/equatable.dart';
import 'map_user.dart';

enum MapStatusFilter { all, online, offline }

enum MapDistanceFilter { all, nearby }

/// The active filter selection (FR-016/017/018), retained for the session
/// (FR-021) and applied client-side for status/group (instant, SC-004).
class MapFilter extends Equatable {
  const MapFilter({
    this.status = MapStatusFilter.all,
    this.groupId,
    this.distance = MapDistanceFilter.all,
    this.nearbyRadiusKm = 10.0,
  });

  final MapStatusFilter status;

  /// `null` = All groups; otherwise a specific GROUP chat room id.
  final String? groupId;
  final MapDistanceFilter distance;
  final double nearbyRadiusKm;

  /// Status + group predicate only — distance is enforced by which dataset
  /// was fetched (`/map/nearby` vs `/map/visible`), not filtered here.
  bool matches(MapUser user) {
    switch (status) {
      case MapStatusFilter.online:
        if (!user.isOnline) return false;
        break;
      case MapStatusFilter.offline:
        if (user.isOnline) return false;
        break;
      case MapStatusFilter.all:
        break;
    }
    if (groupId != null && !user.groupIds.contains(groupId)) return false;
    return true;
  }

  MapFilter copyWith({
    MapStatusFilter? status,
    String? groupId,
    bool clearGroupId = false,
    MapDistanceFilter? distance,
    double? nearbyRadiusKm,
  }) {
    return MapFilter(
      status: status ?? this.status,
      groupId: clearGroupId ? null : (groupId ?? this.groupId),
      distance: distance ?? this.distance,
      nearbyRadiusKm: nearbyRadiusKm ?? this.nearbyRadiusKm,
    );
  }

  @override
  List<Object?> get props => [status, groupId, distance, nearbyRadiusKm];
}
