import 'package:ciro_chat_app/features/status/domain/entities/music_track.dart';
import 'package:equatable/equatable.dart';

abstract class MusicState extends Equatable {
  const MusicState();

  @override
  List<Object?> get props => [];
}

class MusicInitial extends MusicState {}

class MusicLoading extends MusicState {}

class MusicLoaded extends MusicState {
  final List<MusicTrack> tracks;
  final bool hasMore;

  const MusicLoaded({required this.tracks, this.hasMore = false});

  @override
  List<Object?> get props => [tracks, hasMore];
}

class MusicError extends MusicState {
  final String message;

  const MusicError(this.message);

  @override
  List<Object?> get props => [message];
}
