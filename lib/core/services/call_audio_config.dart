import 'package:livekit_client/livekit_client.dart';

/// Single source of truth for the LiveKit audio configuration used by every
/// call surface (1:1 voice/video, group, avatar). Centralizing it here keeps
/// the WebRTC filter flags identical across all connect sites.
abstract final class CallAudioConfig {
  /// Built-in WebRTC filters only — noise suppression, echo cancellation and
  /// automatic gain control are enabled (FR-Audio-02). Apple Voice Isolation
  /// and typing-noise detection are explicitly disabled (FR-Audio-02a): they
  /// are aggressive AI/gating modes that strip high-frequency consonants and
  /// degrade Google STT accuracy. No third-party processor is attached
  /// (FR-Audio-03).
  static const AudioCaptureOptions captureOptions = AudioCaptureOptions(
    noiseSuppression: true,
    echoCancellation: true,
    autoGainControl: true,
    voiceIsolation: false,
    typingNoiseDetection: false,
  );

  /// The [RoomOptions] every call surface MUST use. Preserves the existing
  /// adaptiveStream / dynacast / iOS broadcast-extension behaviour and attaches
  /// the canonical [captureOptions].
  static RoomOptions roomOptions() => const RoomOptions(
        adaptiveStream: true,
        dynacast: true,
        defaultAudioCaptureOptions: captureOptions,
        defaultScreenShareCaptureOptions: ScreenShareCaptureOptions(
          useiOSBroadcastExtension: true,
        ),
      );
}
