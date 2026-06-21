import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:ciro_chat_app/core/network/dio_client.dart';
import 'package:ciro_chat_app/core/network/socket_service.dart';
import '../models/map_user_model.dart';
import '../models/map_group_model.dart';
import '../models/location_update_model.dart';
import '../../domain/repositories/map_repository.dart' show PresenceUpdate;

abstract class MapRemoteDataSource {
  Future<List<MapUserModel>> getVisibleUsers();
  Future<List<MapUserModel>> getNearbyUsers({
    required double longitude,
    required double latitude,
    required double radiusKm,
  });
  Future<List<MapUserModel>> getExploreUsers();
  Future<List<MapGroupModel>> getGroups();
  Future<bool> setGhostMode(bool enabled);
  Future<bool> getGhostMode();
  void shareLocation({required double longitude, required double latitude});

  Stream<PresenceUpdate> get onUserStatusChanged;
  Stream<List<LocationUpdateModel>> get onLocationUpdate;
  Stream<String> get onLocationHidden;

  void dispose();
}

@LazySingleton(as: MapRemoteDataSource)
class MapRemoteDataSourceImpl implements MapRemoteDataSource {
  MapRemoteDataSourceImpl(this._dioClient, this._socketService) {
    _socketService.addUserStatusListener(_handleUserStatus);
    _socketService.onLocationUpdate = _handleLocationUpdate;
    _socketService.onLocationHidden = _handleLocationHidden;
  }

  final DioClient _dioClient;
  final SocketService _socketService;

  final _userStatusController = StreamController<PresenceUpdate>.broadcast();
  final _locationUpdateController =
      StreamController<List<LocationUpdateModel>>.broadcast();
  final _locationHiddenController = StreamController<String>.broadcast();

  void _handleUserStatus(String userId, bool isOnline) {
    _userStatusController.add((userId: userId, isOnline: isOnline));
  }

  void _handleLocationUpdate(List<Map<String, dynamic>> updates) {
    _locationUpdateController.add(
      updates.map(LocationUpdateModel.fromJson).toList(),
    );
  }

  void _handleLocationHidden(String userId) {
    _locationHiddenController.add(userId);
  }

  @override
  Stream<PresenceUpdate> get onUserStatusChanged => _userStatusController.stream;

  @override
  Stream<List<LocationUpdateModel>> get onLocationUpdate =>
      _locationUpdateController.stream;

  @override
  Stream<String> get onLocationHidden => _locationHiddenController.stream;

  @override
  Future<List<MapUserModel>> getVisibleUsers() async {
    final response = await _dioClient.dio.get('/map/visible');
    final users = (response.data['users'] as List?) ?? const [];
    return users
        .map((e) => MapUserModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<List<MapUserModel>> getNearbyUsers({
    required double longitude,
    required double latitude,
    required double radiusKm,
  }) async {
    final response = await _dioClient.dio.get(
      '/map/nearby',
      queryParameters: {
        'longitude': longitude,
        'latitude': latitude,
        'radius': radiusKm,
      },
    );
    final users = (response.data['users'] as List?) ?? const [];
    return users
        .map((e) => MapUserModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<List<MapUserModel>> getExploreUsers() async {
    final response = await _dioClient.dio.get('/map/explore');
    final users = (response.data['users'] as List?) ?? const [];
    return users
        .map((e) => MapUserModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<List<MapGroupModel>> getGroups() async {
    final response = await _dioClient.dio.get('/map/groups');
    final groups = (response.data['groups'] as List?) ?? const [];
    return groups
        .map((e) => MapGroupModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<bool> setGhostMode(bool enabled) async {
    final response = await _dioClient.dio.patch(
      '/map/ghost-mode',
      data: {'enabled': enabled},
    );
    return response.data['isGhostMode'] == true;
  }

  @override
  Future<bool> getGhostMode() async {
    final response = await _dioClient.dio.get('/map/ghost-mode');
    return response.data['isGhostMode'] == true;
  }

  @override
  void shareLocation({required double longitude, required double latitude}) {
    _socketService.shareLocation(longitude: longitude, latitude: latitude);
  }

  @override
  void dispose() {
    _socketService.removeUserStatusListener(_handleUserStatus);
    _socketService.onLocationUpdate = null;
    _socketService.onLocationHidden = null;
    _userStatusController.close();
    _locationUpdateController.close();
    _locationHiddenController.close();
  }
}
