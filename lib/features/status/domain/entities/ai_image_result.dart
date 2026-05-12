import 'package:equatable/equatable.dart';

class AIImageResult extends Equatable {
  final String generationId;
  final String prompt;
  final String imageUrl;
  final DateTime createdAt;

  const AIImageResult({
    required this.generationId,
    required this.prompt,
    required this.imageUrl,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        generationId,
        prompt,
        imageUrl,
        createdAt,
      ];
}
