import 'package:ciro_chat_app/features/status/domain/entities/status_audience_contact.dart';

class StatusAudienceContactModel extends StatusAudienceContact {
  const StatusAudienceContactModel({
    required super.userId,
    required super.name,
    required super.phoneNumber,
    required super.avatarUrl,
  });

  factory StatusAudienceContactModel.fromJson(Map<String, dynamic> json) {
    return StatusAudienceContactModel(
      userId: json['userId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String? ?? '',
    );
  }
}
