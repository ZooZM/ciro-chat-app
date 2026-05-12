import 'package:ciro_chat_app/features/status/data/datasources/music_remote_data_source.dart';
import 'package:ciro_chat_app/features/status/domain/entities/music_track.dart';
import 'package:ciro_chat_app/features/status/domain/repositories/music_repository.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: MusicRepository)
class MusicRepositoryImpl implements MusicRepository {
  final MusicRemoteDataSource remoteDataSource;

  MusicRepositoryImpl(this.remoteDataSource);

  @override
  Future<List<MusicTrack>> getTracks({
    String? query,
    String? category,
    int page = 1,
    int limit = 20,
  }) async {
    return remoteDataSource.fetchTracks(
      query: query,
      category: category,
      page: page,
      limit: limit,
    );
  }

  @override
  Future<List<String>> getCategories() async {
    return remoteDataSource.fetchCategories();
  }
}
