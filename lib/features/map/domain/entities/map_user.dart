import 'package:equatable/equatable.dart';

/// Replaces the mock `MockUser`/`MockMapMarker` with a real, live contact on
/// the map (018-snap-map-realtime). `lastUpdatedAt` is server-assigned and
/// drives both idempotent ordering (FR-022a) and TTL cleanup (FR-003c).
class MapUser extends Equatable {
  const MapUser({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.isOnline,
    required this.latitude,
    required this.longitude,
    required this.lastUpdatedAt,
    this.groupIds = const [],
    this.isCoarse = false,
    this.isCurrentUser = false,
  });

  final String id;
  final String name;
  final String? avatarUrl;
  final bool isOnline;
  final double latitude;
  final double longitude;
  final DateTime lastUpdatedAt;
  final List<String> groupIds;

  /// True when coordinates were coarsened server-side for the Explore tab
  /// (non-contact, FR-001b) — precise live tracking is disabled for this marker.
  final bool isCoarse;
  final bool isCurrentUser;

  /// One initial letter, used as the marker placeholder fallback (FR-027).
  String get initial => name.isNotEmpty ? name[0].toUpperCase() : '?';

  MapUser copyWith({
    String? name,
    String? avatarUrl,
    bool? isOnline,
    double? latitude,
    double? longitude,
    DateTime? lastUpdatedAt,
    List<String>? groupIds,
    bool? isCoarse,
  }) {
    return MapUser(
      id: id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isOnline: isOnline ?? this.isOnline,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      groupIds: groupIds ?? this.groupIds,
      isCoarse: isCoarse ?? this.isCoarse,
      isCurrentUser: isCurrentUser,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    avatarUrl,
    isOnline,
    latitude,
    longitude,
    lastUpdatedAt,
    groupIds,
    isCoarse,
    isCurrentUser,
  ];
}
