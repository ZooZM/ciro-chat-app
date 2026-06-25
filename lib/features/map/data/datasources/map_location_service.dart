import 'dart:async';
import 'dart:io';

import 'package:geolocator/geolocator.dart';
import 'package:injectable/injectable.dart';
import 'package:permission_handler/permission_handler.dart';

/// Wraps `geolocator` permission + position capture (FR-007), broadcasting
/// on significant movement (50m) OR a 30s heartbeat while sharing — R4.
///
/// Location sharing is meant to keep working while the app is backgrounded
/// (not just foregrounded), so [start] always requests "Always"/background
/// authorization and configures a real Android foreground service (visible,
/// persistent notification — required by the OS for background location) /
/// iOS background location updates, rather than the plain foreground-only
/// position stream used elsewhere (e.g. one-shot `locateMe`).
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

  /// Requests foreground permission; returns `true` if granted (FR-007).
  /// Does not capture/send any coordinate until this resolves true. This is
  /// the foreground-only tier — fine for a one-shot fix (`locateMe`), but
  /// [start] additionally escalates to background ("Always") permission.
  Future<bool> requestPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Escalates to background ("Always") location authorization, required on
  /// both platforms for [start]'s position stream to keep delivering once
  /// the app is backgrounded. Must be called after foreground permission is
  /// already granted — Android/iOS both reject requesting both tiers at once.
  Future<bool> requestBackgroundPermission() async {
    final status = await Permission.locationAlways.request();
    return status.isGranted;
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
  /// or the heartbeat interval, whichever first (FR-006) — and keeps doing
  /// so while the app is backgrounded (not killed), via a foreground service
  /// on Android and background location updates on iOS.
  Future<void> start(void Function(double longitude, double latitude) onPosition) async {
    if (!await hasPermission()) return;
    _onPosition = onPosition;
    await stop();

    _positionSub = Geolocator.getPositionStream(
      locationSettings: _backgroundCapableSettings(),
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

  LocationSettings _backgroundCapableSettings() {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: _distanceFilterMeters,
        // Required by Android for any location work to continue once the
        // app is backgrounded — shows the persistent notification the OS
        // mandates for an active foreground service.
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Sharing your location',
          notificationText: 'Ciro is sharing your live location with contacts.',
          notificationIcon: AndroidResource(name: 'ic_notification', defType: 'drawable'),
          setOngoing: true,
          enableWakeLock: true,
        ),
      );
    }
    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: _distanceFilterMeters,
        allowBackgroundLocationUpdates: true,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    }
    return LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: _distanceFilterMeters,
    );
  }

  /// Stops broadcasting outright (explicit "Stop Sharing"), dropping the
  /// permission/last-known state so [resume] has nothing to pick back up —
  /// distinct from simply not being called while backgrounded, since the
  /// background-capable stream above is designed to keep running then.
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
