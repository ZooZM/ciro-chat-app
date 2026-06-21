import 'package:ciro_chat_app/features/status/domain/entities/status_viewer.dart';

class StatusViewerModel extends StatusViewer {
  const StatusViewerModel({
    required super.userId,
    required super.name,
    required super.avatarUrl,
    required super.viewedAt,
  });

  factory StatusViewerModel.fromJson(Map<String, dynamic> json) {
    return StatusViewerModel(
      userId: json['userId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String? ?? '',
      viewedAt: json['viewedAt'] != null
          ? DateTime.parse(json['viewedAt'] as String).toLocal()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'name': name,
      'avatarUrl': avatarUrl,
      'viewedAt': viewedAt.toUtc().toIso8601String(),
    };
  }
}
