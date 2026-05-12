import 'package:ciro_chat_app/features/status/domain/entities/music_track.dart';
import 'package:ciro_chat_app/features/status/domain/repositories/music_repository.dart';
import 'package:ciro_chat_app/features/status/presentation/bloc/music_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:just_audio/just_audio.dart';

@injectable
class MusicCubit extends Cubit<MusicState> {
  final MusicRepository musicRepository;
  final AudioPlayer _audioPlayer = AudioPlayer();
  int _currentPage = 1;
  String? _currentQuery;
  String? _currentCategory;
  bool _isLoadingMore = false;

  MusicCubit(this.musicRepository) : super(MusicInitial());

  Future<void> loadTracks({String? query, String? category}) async {
    emit(MusicLoading());
    _currentPage = 1;
    _currentQuery = query;
    _currentCategory = category;

    try {
      final tracks = await musicRepository.getTracks(
        query: query,
        category: category,
        page: _currentPage,
      );
      emit(MusicLoaded(tracks: tracks, hasMore: tracks.length == 20)); // assuming limit 20
    } catch (e) {
      emit(MusicError(e.toString()));
    }
  }

  Future<void> searchTracks(String query) async {
    await loadTracks(query: query, category: _currentCategory);
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || state is! MusicLoaded) return;
    
    final currentState = state as MusicLoaded;
    if (!currentState.hasMore) return;

    _isLoadingMore = true;
    _currentPage++;

    try {
      final newTracks = await musicRepository.getTracks(
        query: _currentQuery,
        category: _currentCategory,
        page: _currentPage,
      );
      emit(MusicLoaded(
        tracks: [...currentState.tracks, ...newTracks],
        hasMore: newTracks.length == 20,
      ));
    } catch (e) {
      // Don't emit error state to preserve existing tracks, maybe show toast
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<void> previewTrack(MusicTrack track) async {
    try {
      await _audioPlayer.setUrl(track.previewUrl);
      _audioPlayer.play();
    } catch (e) {
      // handle playback error
    }
  }
  
  void stopPreview() {
    _audioPlayer.stop();
  }

  void selectTrack(MusicTrack track) {
    // Selection logic handled by UI -> calls attachMusicTrack on StatusCreationCubit
    stopPreview();
  }

  @override
  Future<void> close() {
    _audioPlayer.dispose();
    return super.close();
  }
}
