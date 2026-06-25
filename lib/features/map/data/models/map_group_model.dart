import '../../domain/entities/map_group.dart';

class MapGroupModel {
  const MapGroupModel({
    required this.id,
    required this.name,
    required this.memberCount,
    this.avatarUrl,
    required this.initials,
  });

  final String id;
  final String name;
  final int memberCount;
  final String? avatarUrl;
  final String initials;

  factory MapGroupModel.fromJson(Map<String, dynamic> json) {
    return MapGroupModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
      avatarUrl: json['avatarUrl']?.toString(),
      initials: json['initials']?.toString() ?? '',
    );
  }

  MapGroup toEntity() {
    return MapGroup(
      id: id,
      name: name,
      memberCount: memberCount,
      avatarUrl: avatarUrl,
      initials: initials,
    );
  }
}
