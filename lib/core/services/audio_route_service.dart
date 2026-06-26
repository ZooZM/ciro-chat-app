import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:livekit_client/livekit_client.dart';

/// Output destinations for active-call audio.
enum AudioOutputRoute { earpiece, speaker, bluetooth }

class AudioOutputDeviceInfo {
  final String id;
  final String label;
  final AudioOutputRoute route;
  const AudioOutputDeviceInfo({required this.id, required this.label, required this.route});
}

class AudioRouteState {
  final AudioOutputRoute activeRoute;
  final List<AudioOutputDeviceInfo> availableRoutes;
  final String? bluetoothName;

  const AudioRouteState({
    this.activeRoute = AudioOutputRoute.earpiece,
    this.availableRoutes = const [],
    this.bluetoothName,
  });

  AudioRouteState copyWith({
    AudioOutputRoute? activeRoute,
    List<AudioOutputDeviceInfo>? availableRoutes,
    String? bluetoothName,
  }) =>
      AudioRouteState(
        activeRoute: activeRoute ?? this.activeRoute,
        availableRoutes: availableRoutes ?? this.availableRoutes,
        bluetoothName: bluetoothName ?? this.bluetoothName,
      );
}

abstract class AudioRouteService {
  Stream<AudioRouteState> get routeStream;
  AudioRouteState get current;

  Future<void> start();
  Future<void> applyDefaultForCall({required bool isVideo});
  Future<void> selectRoute(AudioOutputRoute route, {String? deviceId});
  Future<void> setSpeakerphoneOn(bool on);

  /// Per-call teardown: stop observing device changes but keep the (singleton)
  /// broadcast controller alive for the next call (§V).
  Future<void> stop();

  /// App-shutdown teardown.
  Future<void> dispose();
}

/// Wraps LiveKit [Hardware] for output routing (FR-VoIP-07/08/09/10).
///
/// CRITICAL (FR-VoIP-11 / Constraint): this service routes ONLY through
/// `Hardware.instance` — it MUST NOT call `AudioSession.configure`, so the
/// feature-019 voiceChat session and its noise-cancellation capture options
/// (`CallAudioConfig.captureOptions`) are preserved untouched.
@LazySingleton(as: AudioRouteService)
class AudioRouteServiceImpl implements AudioRouteService {
  final _controller = StreamController<AudioRouteState>.broadcast();
  StreamSubscription<List<MediaDevice>>? _deviceSub;
  AudioRouteState _state = const AudioRouteState();
  bool _isVideoCall = false;

  @override
  Stream<AudioRouteState> get routeStream => _controller.stream;

  @override
  AudioRouteState get current => _state;

  @override
  Future<void> start() async {
    _deviceSub?.cancel();
    _deviceSub = Hardware.instance.onDeviceChange.stream.listen((_) async {
      await _refreshDevices();
    });
    await _refreshDevices();
  }

  @override
  Future<void> applyDefaultForCall({required bool isVideo}) async {
    _isVideoCall = isVideo;
    await _refreshDevices();
    // Bluetooth wins when present; else speaker for video / earpiece for voice.
    if (_hasBluetooth()) {
      await selectRoute(AudioOutputRoute.bluetooth);
    } else {
      await selectRoute(isVideo ? AudioOutputRoute.speaker : AudioOutputRoute.earpiece);
    }
  }

  @override
  Future<void> selectRoute(AudioOutputRoute route, {String? deviceId}) async {
    try {
      switch (route) {
        case AudioOutputRoute.speaker:
          await Hardware.instance.setSpeakerphoneOn(true);
          break;
        case AudioOutputRoute.earpiece:
          await Hardware.instance.setSpeakerphoneOn(false);
          break;
        case AudioOutputRoute.bluetooth:
          // Disabling speaker lets the OS route to the connected BT device.
          await Hardware.instance.setSpeakerphoneOn(false);
          final btId = deviceId ?? _bluetoothDevice()?.id;
          final btDevice = (await Hardware.instance.audioOutputs())
              .where((d) => d.deviceId == btId)
              .firstOrNull;
          if (btDevice != null) {
            await Hardware.instance.selectAudioOutput(btDevice);
          }
          break;
      }
      _emit(_state.copyWith(activeRoute: route));
    } catch (e) {
      debugPrint('[AudioRouteService] selectRoute($route) failed: $e');
    }
  }

  @override
  Future<void> setSpeakerphoneOn(bool on) =>
      selectRoute(on ? AudioOutputRoute.speaker : AudioOutputRoute.earpiece);

  Future<void> _refreshDevices() async {
    try {
      final outputs = await Hardware.instance.audioOutputs();
      final routes = <AudioOutputDeviceInfo>[
        const AudioOutputDeviceInfo(id: 'earpiece', label: 'Earpiece', route: AudioOutputRoute.earpiece),
        const AudioOutputDeviceInfo(id: 'speaker', label: 'Speakerphone', route: AudioOutputRoute.speaker),
      ];
      AudioOutputDeviceInfo? bt;
      for (final d in outputs) {
        if (_isBluetoothLabel(d.label)) {
          bt = AudioOutputDeviceInfo(id: d.deviceId, label: d.label, route: AudioOutputRoute.bluetooth);
          routes.add(bt);
          break;
        }
      }

      // If the active route disappeared (e.g. BT unplugged), fall back (FR-VoIP-09).
      var active = _state.activeRoute;
      if (active == AudioOutputRoute.bluetooth && bt == null) {
        active = _isVideoCall ? AudioOutputRoute.speaker : AudioOutputRoute.earpiece;
        await Hardware.instance.setSpeakerphoneOn(_isVideoCall);
      }

      _emit(AudioRouteState(
        activeRoute: active,
        availableRoutes: routes,
        bluetoothName: bt?.label,
      ));
    } catch (e) {
      debugPrint('[AudioRouteService] refreshDevices failed: $e');
    }
  }

  bool _hasBluetooth() => _state.availableRoutes.any((r) => r.route == AudioOutputRoute.bluetooth);

  AudioOutputDeviceInfo? _bluetoothDevice() =>
      _state.availableRoutes.where((r) => r.route == AudioOutputRoute.bluetooth).firstOrNull;

  bool _isBluetoothLabel(String label) {
    final l = label.toLowerCase();
    return l.contains('bluetooth') || l.contains('headset') || l.contains('airpods') || l.contains('bt');
  }

  void _emit(AudioRouteState state) {
    _state = state;
    if (!_controller.isClosed) _controller.add(state);
  }

  @override
  Future<void> stop() async {
    await _deviceSub?.cancel();
    _deviceSub = null;
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }
}
