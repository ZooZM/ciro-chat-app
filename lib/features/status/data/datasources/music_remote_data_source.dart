import 'package:ciro_chat_app/core/network/dio_client.dart';
import 'package:ciro_chat_app/features/status/data/models/music_track_model.dart';
import 'package:injectable/injectable.dart';

abstract class MusicRemoteDataSource {
  Future<List<MusicTrackModel>> fetchTracks({
    String? query,
    String? category,
    int page = 1,
    int limit = 20,
  });

  Future<List<String>> fetchCategories();
}

@LazySingleton(as: MusicRemoteDataSource)
class MusicRemoteDataSourceImpl implements MusicRemoteDataSource {
  final DioClient dioClient;

  MusicRemoteDataSourceImpl(this.dioClient);

  @override
  Future<List<MusicTrackModel>> fetchTracks({
    String? query,
    String? category,
    int page = 1,
    int limit = 20,
  }) async {
    final response = await dioClient.dio.get(
      '/music/tracks',
      queryParameters: {
        if (query != null && query.isNotEmpty) 'query': query,
        if (category != null && category.isNotEmpty) 'category': category,
        'page': page,
        'limit': limit,
      },
    );

    final List<dynamic> data = response.data['tracks'];
    return data.map((json) => MusicTrackModel.fromJson(json)).toList();
  }

  @override
  Future<List<String>> fetchCategories() async {
    final response = await dioClient.dio.get('/music/categories');
    final List<dynamic> data = response.data['categories'];
    return data.cast<String>();
  }
}
