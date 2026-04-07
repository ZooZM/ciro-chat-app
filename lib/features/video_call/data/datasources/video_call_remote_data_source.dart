import 'package:injectable/injectable.dart';
import '../../../../core/network/dio_client.dart';

abstract class VideoCallRemoteDataSource {
  Future<String> fetchLiveKitToken(String roomId);
}

@LazySingleton(as: VideoCallRemoteDataSource)
class VideoCallRemoteDataSourceImpl implements VideoCallRemoteDataSource {
  final DioClient _dioClient;

  VideoCallRemoteDataSourceImpl(this._dioClient);

  @override
  Future<String> fetchLiveKitToken(String roomId) async {
    final response = await _dioClient.dio.post('/video/room/$roomId/join');
    
    // Attempting to extract the token robustly
    if (response.data is Map<String, dynamic>) {
      final data = response.data as Map<String, dynamic>;
      
      if (data.containsKey('data') && data['data'] is Map<String, dynamic>) {
        final nestedData = data['data'] as Map<String, dynamic>;
        if (nestedData.containsKey('token')) return nestedData['token'] as String;
      }

      if (data.containsKey('token')) return data['token'] as String;
      if (data.containsKey('accessToken')) return data['accessToken'] as String;
    }
    
    throw Exception('Failed to extract LiveKit token from response. Keys: ${response.data}');
  }
}
