import 'package:ciro_chat_app/features/status/domain/entities/music_track.dart';

abstract class MusicRepository {
  Future<List<MusicTrack>> getTracks({
    String? query,
    String? category,
    int page = 1,
    int limit = 20,
  });

  Future<List<String>> getCategories();
}
