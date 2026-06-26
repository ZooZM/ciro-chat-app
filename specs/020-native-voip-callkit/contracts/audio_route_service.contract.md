# Contract: AudioRouteService (core/services/audio_route_service.dart)

Wraps LiveKit `Hardware.instance` for output routing. **MUST NOT** call `AudioSession.configure` or alter `CallAudioConfig` — output selection only, preserving feature-019 noise cancellation (FR-VoIP-11, Constraint).

```dart
abstract interface class AudioRouteService {
  /// Current + available routes; emits on every change (incl. BT connect/disconnect).
  Stream<AudioRouteState> get routeStream;
  AudioRouteState get current;

  /// Begin observing device changes for an active call. Call after room.connect().
  Future<void> start();

  /// Apply the default route at connect: BT if present, else
  /// speaker for video / earpiece for voice (FR-VoIP-10).
  Future<void> applyDefaultForCall({required bool isVideo});

  /// Switch to a specific route chosen from the picker (FR-VoIP-07).
  Future<void> selectRoute(AudioOutputRoute route, {String? deviceId});

  /// Fast earpiece↔speaker toggle (back-compat with existing button).
  Future<void> setSpeakerphoneOn(bool on);

  /// Stop observing + cancel subscriptions (call on call end, §V).
  Future<void> dispose();
}

enum AudioOutputRoute { earpiece, speaker, bluetooth }

class AudioRouteState {
  final AudioOutputRoute activeRoute;
  final List<AudioOutputDeviceInfo> availableRoutes;
  final String? bluetoothName;
  const AudioRouteState({
    required this.activeRoute,
    this.availableRoutes = const [],
    this.bluetoothName,
  });
}

class AudioOutputDeviceInfo {
  final String id;
  final String label;
  final AudioOutputRoute route;
  const AudioOutputDeviceInfo({required this.id, required this.label, required this.route});
}
```

### Behavioural contract

1. `selectRoute` audible effect within 1s (SC-004); `routeStream` reflects the actual active route 100% of changes (SC-005).
2. On Bluetooth disconnect mid-call, MUST auto-fallback to the type default and emit on `routeStream` (FR-VoIP-09).
3. MUST route exclusively through `Hardware.instance` (`audioOutputs`, `selectAudioOutput`, `setSpeakerphoneOn`); MUST NOT reconfigure the audio session (regression test asserts `CallAudioConfig.captureOptions` unchanged — SC-006).
4. Best-effort: failures `debugPrint` and never throw into the call screen.

### UI contract: audio_route_picker_sheet.dart

- Opened by the active-call **speaker icon** button.
- Lists every `availableRoutes` entry; active route shows a check/highlight.
- Rows: Earpiece (`Icons.hearing`/`phone_in_talk`), Speakerphone (`Icons.volume_up`), Bluetooth device by name (`Icons.bluetooth_audio`).
- Selecting a row calls `selectRoute` and dismisses; sheet updates live if `routeStream` changes while open.
- Speaker button icon reflects `activeRoute` per data-model (FR-VoIP-08).
