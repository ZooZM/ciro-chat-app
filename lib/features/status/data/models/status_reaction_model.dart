import 'package:ciro_chat_app/features/status/domain/entities/status_reaction.dart';

class StatusReactionModel extends StatusReaction {
  const StatusReactionModel({
    required super.userId,
    required super.reaction,
    required super.createdAt,
  });

  factory StatusReactionModel.fromJson(Map<String, dynamic> json) {
    return StatusReactionModel(
      userId: json['userId'] as String? ?? '',
      reaction: json['reaction'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'reaction': reaction,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
