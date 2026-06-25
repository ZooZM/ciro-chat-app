import '../../domain/repositories/map_repository.dart';

/// Parses a single item from the batched `locationUpdate { updates: [...] }`
/// socket payload (contracts/socket-events.md). Callers MUST use the IV-A
/// safe pattern (`data is! Map` guard) before reaching this constructor.
class LocationUpdateModel {
  const LocationUpdateModel({
    required this.userId,
    required this.longitude,
    required this.latitude,
    required this.isOnline,
    required this.lastUpdatedAt,
  });

  final String userId;
  final double longitude;
  final double latitude;
  final bool isOnline;
  final DateTime lastUpdatedAt;

  factory LocationUpdateModel.fromJson(Map<String, dynamic> json) {
    final rawUpdatedAt = json['lastUpdatedAt']?.toString();
    return LocationUpdateModel(
      userId: json['userId']?.toString() ?? '',
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      isOnline: json['isOnline'] == true,
      lastUpdatedAt: rawUpdatedAt != null
          ? DateTime.tryParse(rawUpdatedAt) ?? DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  LocationUpdate toEntity() {
    return LocationUpdate(
      userId: userId,
      longitude: longitude,
      latitude: latitude,
      isOnline: isOnline,
      lastUpdatedAt: lastUpdatedAt,
    );
  }
}
