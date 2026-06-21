import 'package:ciro_chat_app/features/status/domain/entities/ai_image_result.dart';

class AIImageResultModel extends AIImageResult {
  const AIImageResultModel({
    required super.generationId,
    required super.prompt,
    required super.imageUrl,
    required super.createdAt,
  });

  factory AIImageResultModel.fromJson(Map<String, dynamic> json) {
    return AIImageResultModel(
      generationId: json['generationId'] as String,
      prompt: json['prompt'] as String,
      imageUrl: json['imageUrl'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    );
  }
}
