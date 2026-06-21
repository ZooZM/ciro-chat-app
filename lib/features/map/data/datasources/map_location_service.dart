import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:injectable/injectable.dart';

/// Wraps `geolocator` permission + position capture (FR-007), broadcasting
/// on significant movement (50m) OR a 30s heartbeat while sharing — R4.
@LazySingleton()
class MapLocationService {
  StreamSubscription<Position>? _positionSub;
  Timer? _heartbeatTimer;
  Position? _lastPosition;
  void Function(double longitude, double latitude)? _onPosition;

  static const _distanceFilterMeters = 50;
  static const _heartbeatInterval = Duration(seconds: 30);

  Future<bool> hasPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Requests permission; returns `true` if granted (FR-007). Does not
  /// capture/send any coordinate until this resolves true.
  Future<bool> requestPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<Position?> getCurrentPosition() async {
    if (!await hasPermission()) return null;
    try {
      return await Geolocator.getCurrentPosition();
    } catch (_) {
      return null;
    }
  }

  /// Starts broadcasting position via [onPosition] on significant movement
  /// or the heartbeat interval, whichever first (FR-006).
  Future<void> start(void Function(double longitude, double latitude) onPosition) async {
    if (!await hasPermission()) return;
    _onPosition = onPosition;
    await stop();

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: _distanceFilterMeters,
      ),
    ).listen((position) {
      _lastPosition = position;
      _onPosition?.call(position.longitude, position.latitude);
    });

    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      final position = _lastPosition;
      if (position != null) {
        _onPosition?.call(position.longitude, position.latitude);
      }
    });
  }

  /// Pauses broadcasting (app backgrounded, FR-031) without dropping the
  /// permission/last-known state, so [resume] can pick back up.
  Future<void> stop() async {
    await _positionSub?.cancel();
    _positionSub = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<void> resume() async {
    final callback = _onPosition;
    if (callback != null) await start(callback);
  }

  void dispose() {
    _positionSub?.cancel();
    _heartbeatTimer?.cancel();
    _onPosition = null;
  }
}
