import 'package:equatable/equatable.dart';

class MusicTrack extends Equatable {
  final String id;
  final String name;
  final String artist;
  final Duration duration;
  final String thumbnailUrl;
  final String previewUrl;
  final String category;

  const MusicTrack({
    required this.id,
    required this.name,
    required this.artist,
    required this.duration,
    required this.thumbnailUrl,
    required this.previewUrl,
    required this.category,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        artist,
        duration,
        thumbnailUrl,
        previewUrl,
        category,
      ];
}
