import 'package:ciro_chat_app/features/reels/domain/entities/reels_page.dart';
import 'reel_model.dart';

class ReelsPageModel extends ReelsPage {
  const ReelsPageModel({required super.items, required super.nextCursor});

  factory ReelsPageModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];
    return ReelsPageModel(
      items: rawItems
          .map((e) => ReelModel.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      nextCursor: json['nextCursor'] as String?,
    );
  }
}
