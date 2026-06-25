import '../../domain/entities/map_user.dart';

/// Parses the `/map/visible`, `/map/nearby`, `/map/explore` REST response
/// item shape (contracts/rest-api.md) into a [MapUser].
class MapUserModel {
  const MapUserModel({
    required this.id,
    required this.name,
    this.phoneNumber,
    this.avatarUrl,
    required this.isOnline,
    required this.latitude,
    required this.longitude,
    required this.lastUpdatedAt,
    this.groupIds = const [],
    this.isCoarse = false,
  });

  final String id;
  final String name;
  final String? phoneNumber;
  final String? avatarUrl;
  final bool isOnline;
  final double latitude;
  final double longitude;
  final DateTime lastUpdatedAt;
  final List<String> groupIds;
  final bool isCoarse;

  factory MapUserModel.fromJson(Map<String, dynamic> json) {
    final location = json['location'] as Map<String, dynamic>?;
    final coordinates = (location?['coordinates'] as List?) ?? const [0, 0];
    final lng = (coordinates[0] as num?)?.toDouble() ?? 0.0;
    final lat = (coordinates[1] as num?)?.toDouble() ?? 0.0;
    final rawUpdatedAt = json['locationUpdatedAt']?.toString();

    return MapUserModel(
      id: json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      phoneNumber: json['phoneNumber']?.toString(),
      avatarUrl: json['avatarUrl']?.toString(),
      isOnline: json['isOnline'] == true,
      longitude: lng,
      latitude: lat,
      lastUpdatedAt: rawUpdatedAt != null
          ? DateTime.tryParse(rawUpdatedAt) ?? DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.fromMillisecondsSinceEpoch(0),
      groupIds: ((json['sharedGroupIds'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      isCoarse: json['isCoarse'] == true,
    );
  }

  MapUser toEntity() {
    return MapUser(
      id: id,
      name: name,
      phoneNumber: phoneNumber,
      avatarUrl: avatarUrl,
      isOnline: isOnline,
      latitude: latitude,
      longitude: longitude,
      lastUpdatedAt: lastUpdatedAt,
      groupIds: groupIds,
      isCoarse: isCoarse,
    );
  }
}
