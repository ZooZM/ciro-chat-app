import 'package:ciro_chat_app/features/status/domain/entities/music_track.dart';

class MusicTrackModel extends MusicTrack {
  const MusicTrackModel({
    required super.id,
    required super.name,
    required super.artist,
    required super.duration,
    required super.thumbnailUrl,
    required super.previewUrl,
    required super.category,
  });

  factory MusicTrackModel.fromJson(Map<String, dynamic> json) {
    return MusicTrackModel(
      id: json['id'] as String,
      name: json['name'] as String,
      artist: json['artist'] as String,
      duration: Duration(seconds: json['duration_seconds'] as int),
      thumbnailUrl: json['thumbnailUrl'] as String,
      previewUrl: json['previewUrl'] as String,
      category: json['category'] as String,
    );
  }
}
