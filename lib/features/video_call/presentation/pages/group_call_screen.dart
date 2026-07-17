import 'dart:async';
import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:ciro_chat_app/core/di/injection.dart';
import 'package:ciro_chat_app/core/services/audio_route_service.dart';
import 'package:ciro_chat_app/core/services/call_audio_config.dart';
import 'package:ciro_chat_app/core/services/call_audio_session_service.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ciro_chat_app/core/helpers/permission_service.dart';
import '../bloc/call_cubit.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../domain/repositories/video_call_repository.dart';
import '../widgets/audio_route_picker_sheet.dart';
import '../widgets/screen_share_tile.dart';
import '../widgets/minimized_call.dart';
import '../widgets/call_more_options_sheet.dart';
import '../../../chat/data/datasources/chat_local_data_source.dart';
import '../../../call_recording/presentation/bloc/call_recording_cubit.dart';
import '../../../translation/domain/entities/caption.dart';
import '../../../translation/domain/entities/supported_languages.dart';
import '../../../translation/domain/entities/translation_subscription.dart';
import '../../../translation/presentation/bloc/translation_cubit.dart';
import '../../../translation/presentation/bloc/translation_state.dart';
import '../../../translation/presentation/widgets/caption_overlay.dart';
import '../../../translation/presentation/widgets/subtitle_overlay_widget.dart';
import '../../../translation/presentation/widgets/translation_toggle_sheet.dart';

import 'dart:ui';
// ─────────────────────────────────────────────────────────────────────────────
// Palette (matches the mockup exactly)
// ─────────────────────────────────────────────────────────────────────────────
const _kBg = Color(0xFFEA4071); // dark pink background
const _kControlsBg = Color(0xFF3B3B3B); // controls panel
const _kGreen = Color(0xFF4CAF50);
const _kBtnGray = Color(0xFF757575);

// Tile colour palette (matches screenshot order)
const _kTileColors = [
  Color(0xFF8BC34A), // light-green  (index 0)
  Color(0xFF388E3C), // dark-green   (index 1)
  Color(0xFF7E57C2), // purple       (index 2)
  Color(0xFFBDBDBD), // light-grey   (index 3)
  Color(0xFF4DB6AC), // teal → "You"
];

/// Full-screen group voice/video call screen backed by LiveKit.
class GroupCallScreen extends StatefulWidget {
  final String roomId;

  /// When restoring a minimized group call, the already-connected room is handed
  /// back here so we reuse the same session instead of reconnecting.
  final Room? externalRoom;

  /// Preserved call start time so the timer keeps counting across minimize.
  final DateTime? callStartedAt;

  const GroupCallScreen({
    super.key,
    required this.roomId,
    this.externalRoom,
    this.callStartedAt,
  });

  @override
  State<GroupCallScreen> createState() => _GroupCallScreenState();
}

class _GroupCallScreenState extends State<GroupCallScreen> {
  Room? _room;
  EventsListener<RoomEvent>? _roomEventsListener;
  // Resolved group display name (falls back to roomId until loaded).
  String _groupName = '';
  bool _isConnecting = true;
  bool _isMicMuted = false;
  bool _isCameraDisabled = true; // voice call: camera off by default
  bool _isFrontCamera = true;
  String? _error;

  // Screen-share side-events
  StreamSubscription<CallSideEvent>? _sideEventSub;
  StreamSubscription<CallState>? _callStateSub;
  String _localUserId = '';
  String _localUserName = '';
  String _prevSharerUserId = '';

  // Audio output routing (020-native-voip-callkit) — speaker button (FR-VoIP-07/08)
  late final AudioRouteService _audioRoute = getIt<AudioRouteService>();
  StreamSubscription<AudioRouteState>? _routeSub;
  AudioRouteState _routeState = const AudioRouteState();

  // Timer — a persistent start time so it survives minimize/restore.
  late final DateTime _callStartedAt;
  Timer? _uiTimer;

  // Immersive mode: tap the screen to hide the top bar + bottom controls
  // (matches the 1:1 video call screen).
  bool _controlsVisible = true;
  bool _isEmojiOpen = false;
  bool _isMinimizing = false;
  void _toggleControls() =>
      setState(() => _controlsVisible = !_controlsVisible);

  // Idempotent room teardown — `_endCall`, the CallEnded listener, and dispose
  // can all fire for the same end; disconnecting the LiveKit room twice
  // double-completes the SDK's completer → "Future already completed".
  bool _roomDisconnected = false;
  void _disconnectRoom() {
    if (_roomDisconnected) return;
    _roomDisconnected = true;
    _room?.disconnect();
  }

  // Local "You" tile floats as a draggable, corner-snapping PIP (like 1:1).
  Offset _pipOffset = const Offset(16, 130);
  static const double _pipW = 110;
  static const double _pipH = 150;

  void _snapPipToCorner(Size size) {
    final leftX = 16.resW;
    final rightX = size.width - _pipW.resR - 16.resW;
    final topY = 130.resH; // below the status bar + top bar
    final bottomY = size.height - _pipH.resR - 130.resH; // above the control bar
    final centerX = _pipOffset.dx + _pipW.resR / 2;
    final centerY = _pipOffset.dy + _pipH.resR / 2;
    setState(() {
      _pipOffset = Offset(
        centerX < size.width / 2 ? leftX : rightX,
        centerY < size.height / 2 ? topY : bottomY,
      );
    });
  }

  // Live translation captions (015-live-translation-captions)
  late final TranslationCubit _translationCubit;
  final Set<String> _shownDeniedFor = {};
  // Temporary global data-channel tap — confirms the Room is receiving ANY
  // LiveKit data packets before the datasource's topic filter runs.
  // room.events.listen() returns CancelListenFunc, not StreamSubscription.
  CancelListenFunc? _rawDataDebugSub;

  @override
  void initState() {
    super.initState();
    _translationCubit = getIt<TranslationCubit>();
    _callStartedAt = widget.callStartedAt ?? DateTime.now();
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    // Resolve the group's display name from the local chat session.
    getIt<ChatLocalDataSource>().getRoomById(widget.roomId).then((session) {
      final name = session?.name ?? '';
      if (mounted && name.isNotEmpty) setState(() => _groupName = name);
    }).catchError((_) {});

    final authState = getIt<AuthCubit>().state;
    if (authState is Authenticated) {
      // verifyOtp returns the user under a nested 'user' map (MongoDB
      // convention: '_id'). Fall back to the top-level map and to 'id' for
      // safety if the backend shape ever flattens.
      final user =
          (authState.userData?['user'] as Map<String, dynamic>?) ??
          authState.userData;
      _localUserId = (user?['_id'] ?? user?['id'])?.toString() ?? '';
      _localUserName = user?['phoneNumber']?.toString() ?? '';
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connectFromCubitState();
      if (!mounted) return;
      final cubit = context.read<CallCubit>();

      _sideEventSub = cubit.sideEvents.listen((event) {
        if (!mounted) return;
        if (event is CallScreenShareConflict) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${event.activeSharerName} is already sharing.'),
            ),
          );
        } else if (event is CallScreenShareDenied) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Screen share permission required.'),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: openAppSettings,
              ),
            ),
          );
        } else if (event is CallMuteRequested) {
          // C1 — native CallKit mute toggle reflected onto the LiveKit track.
          _room?.localParticipant?.setMicrophoneEnabled(!event.muted);
          setState(() => _isMicMuted = event.muted);
        }
      });

      _callStateSub = cubit.stream.listen((state) {
        if (!mounted) return;
        final newId = state is CallActive ? state.activeSharerUserId : '';
        if (newId.isNotEmpty &&
            newId != _localUserId &&
            _prevSharerUserId.isEmpty) {
          final name = state is CallActive ? state.activeSharerName : '';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$name started sharing their screen'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        _prevSharerUserId = newId;
      });
    });
  }

  void _connectFromCubitState() {
    final s = context.read<CallCubit>().state;
    // Restore path: reuse the room handed back from the minimized window.
    if (widget.externalRoom != null) {
      _connectToRoom(
        '',
        '',
        isVideo: false,
        chatRoomId: s is CallActive ? s.chatRoomId : widget.roomId,
        reuseRoom: widget.externalRoom,
      );
      return;
    }
    if (s is CallActive && s.isGroupCall) {
      _connectToRoom(
        s.livekitUrl,
        s.livekitToken,
        isVideo: s.isVideo,
        chatRoomId: s.chatRoomId,
      );
    } else {
      setState(() {
        _error = 'No active group call state found.';
        _isConnecting = false;
      });
    }
  }

  Future<void> _connectToRoom(
    String url,
    String token, {
    bool isVideo = false,
    required String chatRoomId,
    Room? reuseRoom,
  }) async {
    try {
      final reusing = reuseRoom != null;
      if (reusing) {
        // Restore from the minimized window — the room is already connected.
        _room = reuseRoom;
        _isMicMuted = !(_room!.localParticipant?.isMicrophoneEnabled() ?? true);
        _isCameraDisabled =
            !(_room!.localParticipant?.isCameraEnabled() ?? false);
      } else {
        await PermissionService.requestSingle(Permission.microphone);
        if (isVideo) await PermissionService.requestSingle(Permission.camera);

        // Configure the OS voice-communication audio session BEFORE connecting
        // (FR-Audio-01, SC-003).
        await getIt<CallAudioSessionService>().configureForCall();

        _room = Room(roomOptions: CallAudioConfig.roomOptions());
      }
      _room!.addListener(_onRoomUpdate);

      _roomEventsListener = _room!.createListener()
        ..on<LocalTrackPublishedEvent>((_) {
          if (mounted) setState(() {});
        })
        ..on<LocalTrackUnpublishedEvent>((_) {
          if (mounted) setState(() {});
        })
        ..on<TrackSubscribedEvent>((_) {
          if (mounted) setState(() {});
        })
        ..on<TrackUnsubscribedEvent>((_) {
          if (mounted) setState(() {});
        })
        ..on<ParticipantDisconnectedEvent>((event) {
          _translationCubit.removeSpeaker(event.participant.identity);
        });

      if (!reusing) {
        await _room!.connect(url, token);
      }
      debugPrint(
        '[GroupCallScreen] Room ${reusing ? 'reused' : 'connected'}. Calling attachRoom with roomId: $chatRoomId',
      );
      _translationCubit.attachRoom(_room!, roomId: chatRoomId);
      debugPrint(
        '[GroupCallScreen] attachRoom done — TranslationCubit is now listening for captions.',
      );
      _rawDataDebugSub = _room!.events.listen((event) {
        if (event is DataReceivedEvent) {
          debugPrint(
            '[LiveKit RAW] topic: "${event.topic}",'
            ' bytes: ${event.data.length},'
            ' payload: ${utf8.decode(event.data)}',
          );
        }
      });
      getIt<VideoCallRepository>().setExternalRoom(_room!);
      // Keep the WebRTC connection alive when the screen locks (Android).
      getIt<VideoCallRepository>().setCallServiceActive(true);
      if (!reusing) {
        await _room!.localParticipant?.setMicrophoneEnabled(true);
        if (isVideo) await _room!.localParticipant?.setCameraEnabled(true);
      }

      // Default audio route: BT takes precedence, else video→speaker /
      // voice→earpiece (FR-VoIP-10). Output-only — never touches the 019
      // audio session configured above.
      _routeSub = _audioRoute.routeStream.listen((s) {
        if (mounted) setState(() => _routeState = s);
      });
      await _audioRoute.start();
      await _audioRoute.applyDefaultForCall(isVideo: !_isCameraDisabled);

      if (mounted) {
        setState(() {
          _isConnecting = false;
          if (!reusing) _isCameraDisabled = !isVideo;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isConnecting = false;
        });
      }
    }
  }

  void _onRoomUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _endCall() async {
    final recCubit = context.read<CallRecordingCubit>();
    final callCubit = context.read<CallCubit>();
    final router = GoRouter.of(context);
    final canPop = context.canPop();
    if (recCubit.state is RecordingActive) await recCubit.stop();
    await callCubit.leaveGroupCall();
    _disconnectRoom();
    if (mounted) {
      if (canPop) {
        try {
          router.pop();
        } catch (_) {
          router.go('/home');
        }
      } else {
        router.go('/home');
      }
    }
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    _sideEventSub?.cancel();
    _callStateSub?.cancel();
    _routeSub?.cancel();
    _roomEventsListener?.dispose();
    _rawDataDebugSub?.call();
    _room?.removeListener(_onRoomUpdate);
    // Keep the room + translation alive when handing off to the minimized window.
    if (!_isMinimizing) {
      _translationCubit.detachRoom();
      _translationCubit.close();
      getIt<VideoCallRepository>().setCallServiceActive(false);
      getIt<VideoCallRepository>().setExternalRoom(null);
      _disconnectRoom();
      getIt<CallAudioSessionService>().deactivate();
      _audioRoute.stop();
    }
    super.dispose();
  }

  /// Collapses the group call into the floating minimized window; dispose keeps
  /// the room alive via [_isMinimizing]. Restores back into the group screen.
  void _minimizeCall() {
    final room = _room;
    if (room == null) return;
    setState(() => _isMinimizing = true);
    MinimizedCallController.instance.minimize(
      room: room,
      contactName: _groupName.isNotEmpty ? _groupName : 'Group Call',
      isVideo: true,
      livekitUrl: '',
      livekitToken: '',
      startedAt: _callStartedAt,
      groupRoomId: widget.roomId,
    );
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String get _elapsedLabel {
    final s = DateTime.now().difference(_callStartedAt);
    final mm = s.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = s.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocProvider<TranslationCubit>.value(
      value: _translationCubit,
      child: MultiBlocListener(
        listeners: [
          BlocListener<CallCubit, CallState>(
            listener: (context, state) {
              if (state is CallIdle || state is CallEnded) {
                final router = GoRouter.of(context);
                final canPop = context.canPop();
                _disconnectRoom();
                // _endCall and this listener can both fire for the same CallIdle —
                // whichever pops second hits "nothing to pop". Guard with try/catch
                // and fall back to /home if the stack has already unwound.
                if (canPop) {
                  try {
                    router.pop();
                  } catch (_) {
                    router.go('/home');
                  }
                } else {
                  router.go('/home');
                }
              }
            },
          ),
          BlocListener<TranslationCubit, TranslationState>(
            bloc: _translationCubit,
            listener: (context, state) {
              for (final entry in state.subscriptions.entries) {
                if (entry.value.status == TranslationStatus.denied) {
                  if (_shownDeniedFor.add(entry.key)) {
                    final reason = entry.value.deniedReason ?? 'unknown';
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('translation_denied_$reason'.tr()),
                      ),
                    );
                  }
                } else {
                  _shownDeniedFor.remove(entry.key);
                }
              }
            },
          ),
        ],
        child: Scaffold(
          backgroundColor: Colors.black,
          body: _isConnecting
              ? SafeArea(child: _buildConnecting())
              : _error != null
              ? SafeArea(child: _buildError())
              : _buildCallBody(),
        ),
      ),
    );
  }

  Widget _buildConnecting() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(color: Colors.white),
        SizedBox(height: 16.resH),
        Text(
          'call_joining'.tr(),
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ],
    ),
  );

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
    ),
  );

  // ── Main call body ─────────────────────────────────────────────────────────

  Widget _buildCallBody() {
    return BlocBuilder<CallCubit, CallState>(
      builder: (context, state) {
        final callActive = state is CallActive && state.isGroupCall;
        final isRecording = callActive && state.recordingState.isRecording;
        final isSharing = callActive && state.isLocallySharingScreen;
        // Prefer the resolved group name; fall back to a generic label rather
        // than exposing the raw room id.
        final groupName = _groupName.isNotEmpty ? _groupName : 'Group Call';

        final remoteParticipants =
            _room?.remoteParticipants.values.toList() ?? [];
        final participantCount = remoteParticipants.length + 1; // +1 for local

        // Resolve remote screen-share track
        VideoTrack? remoteShareTrack;
        String remoteSharerName = '';
        String remoteSharerUserId = '';
        bool remoteSharerHasAudio = false;
        for (final p in remoteParticipants) {
          final pub = p.videoTrackPublications
              .where((pub) => pub.source == TrackSource.screenShareVideo)
              .firstOrNull;
          if (pub != null) {
            remoteSharerUserId = p.identity;
            remoteSharerName = p.name.isNotEmpty ? p.name : p.identity;
            final t = pub.track;
            if (t is VideoTrack) remoteShareTrack = t;
            remoteSharerHasAudio = p.audioTrackPublications.any(
              (a) => a.source == TrackSource.screenShareAudio,
            );
            break;
          }
        }
        final isMutedLocally =
            callActive &&
            state.mutedScreenAudioBySharerId.contains(remoteSharerUserId);

        // Resolve local screen-share track
        VideoTrack? localShareTrack;
        if (isSharing) {
          final local = _room?.localParticipant;
          if (local != null) {
            var pub = local.videoTrackPublications
                .where((p) => p.source == TrackSource.screenShareVideo)
                .firstOrNull;
            pub ??= local.videoTrackPublications
                .where((p) => p.source != TrackSource.camera)
                .firstOrNull;
            final t = pub?.track;
            if (t is VideoTrack) localShareTrack = t;
          }
        }

        final isWaiting = remoteParticipants.isEmpty && !isSharing;

        // Parent GestureDetector: taps on empty video toggle the controls, while
        // child buttons (CC on tiles, top/bottom bar, PIP) win their own taps via
        // the gesture arena. (A sibling tap layer would steal the CC taps.)
        return GestureDetector(
          onTap: _toggleControls,
          behavior: HitTestBehavior.opaque,
          child: Stack(
          children: [
            Positioned.fill(
              child: isWaiting
                  ? _buildWaitingCenter()
                  : _buildParticipantGrid(
                      remoteParticipants,
                      remoteShareTrack: remoteShareTrack,
                      remoteSharerName: remoteSharerName,
                      remoteSharerUserId: remoteSharerUserId,
                      remoteSharerHasAudio: remoteSharerHasAudio,
                      isMutedLocally: isMutedLocally,
                      showRemoteTile: remoteSharerUserId.isNotEmpty,
                      isSharing: isSharing,
                      localShareTrack: localShareTrack,
                    ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 100, // Above controls
              child: IgnorePointer(
                child: SubtitleOverlayWidget(
                  transcript: _translationCubit.transcriptList,
                  participants: remoteParticipants,
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top,
              left: 0,
              right: 0,
              child: IgnorePointer(
                ignoring: !_controlsVisible,
                child: AnimatedOpacity(
                  opacity: _controlsVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: _buildHeader(
                    groupName: groupName,
                    isWaiting: isWaiting,
                    participantCount: participantCount,
                    isRecording: isRecording,
                    isSharing: isSharing,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                ignoring: !_controlsVisible,
                child: AnimatedOpacity(
                  opacity: _controlsVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: SafeArea(
                    top: false,
                    child: _buildControls(isSharing: isSharing),
                  ),
                ),
              ),
            ),
            // Local "You" — draggable, corner-snapping floating PIP (like 1:1).
            if (!isWaiting)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                left: _pipOffset.dx,
                top: _pipOffset.dy,
                child: GestureDetector(
                  onPanUpdate: (d) {
                    final size = MediaQuery.of(context).size;
                    setState(() {
                      _pipOffset = Offset(
                        (_pipOffset.dx + d.delta.dx)
                            .clamp(0.0, size.width - _pipW.resR),
                        (_pipOffset.dy + d.delta.dy)
                            .clamp(0.0, size.height - _pipH.resR),
                      );
                    });
                  },
                  onPanEnd: (_) => _snapPipToCorner(MediaQuery.of(context).size),
                  child: SizedBox(
                    width: _pipW.resR,
                    height: _pipH.resR,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16.resR),
                      child: _buildLocalTile(),
                    ),
                  ),
                ),
              ),
          ],
          ),
        );
      },
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader({
    required String groupName,
    required bool isWaiting,
    required int participantCount,
    required bool isRecording,
    required bool isSharing,
  }) {
    final displayName = groupName.isNotEmpty ? groupName : 'Group Call';
    final subtitle = isWaiting
        ? 'call_waiting_to_join'.tr()
        : '$_elapsedLabel · ${'call_participants_count'.tr(namedArgs: {'count': '$participantCount'})}';
    // Same top bar as the 1:1 video screen: minimize · avatar · name/subtitle ·
    // (REC) · speaker · end.
    return Padding(
      padding: EdgeInsets.only(top: 16.resH, left: 16.resW, right: 16.resW),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.resW, vertical: 12.resH),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: _minimizeCall,
              child: const Icon(Icons.keyboard_arrow_down,
                  color: Colors.white, size: 28),
            ),
            SizedBox(width: 8.resW),
            CircleAvatar(
              radius: 20.resW,
              backgroundColor: Colors.white.withOpacity(0.2),
              child: Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            SizedBox(width: 12.resW),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.resSp,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.white70, fontSize: 13.resSp),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isRecording) ...[
              const _RecordingBanner(),
              SizedBox(width: 8.resW),
            ],
            // Speaker Button
            GestureDetector(
              onTap: () => AudioRoutePickerSheet.show(context),
              child: Container(
                width: 44.resW,
                height: 44.resW,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  speakerIconForRoute(_routeState.activeRoute),
                  color: Colors.white,
                  size: 22.resW,
                ),
              ),
            ),
            SizedBox(width: 8.resW),
            // End Call Button
            GestureDetector(
              onTap: _endCall,
              child: Container(
                width: 44.resW,
                height: 44.resW,
                decoration: const BoxDecoration(
                  color: Color(0xFFE53935),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.call_end, color: Colors.white, size: 22.resW),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Waiting center ─────────────────────────────────────────────────────────

  Widget _buildWaitingCenter() => Center(
    child: Container(
      width: 160.resW,
      height: 160.resW,
      decoration: const BoxDecoration(
        color: Color(0xFFEEEEEE),
        shape: BoxShape.circle,
      ),
      child: const Center(child: Icon(Icons.group, size: 80, color: _kGreen)),
    ),
  );

  // ── Participant grid ───────────────────────────────────────────────────────

  Widget _buildParticipantGrid(
    List<RemoteParticipant> remoteParticipants, {
    required bool showRemoteTile,
    required VideoTrack? remoteShareTrack,
    required String remoteSharerName,
    required String remoteSharerUserId,
    required bool remoteSharerHasAudio,
    required bool isMutedLocally,
    required bool isSharing,
    required VideoTrack? localShareTrack,
  }) {
    // Grid holds only REMOTE participants — the local "You" tile floats as a
    // draggable PIP (added in _buildCallBody), like the 1:1 video screen.

    // Sharer's view: "You're sharing your screen!" with participants as PIPs.
    if (isSharing) {
      return _buildLocalSharingLayout(remoteParticipants);
    }

    // Viewer's view: a remote is sharing → show their screen prominently with
    // participants as a PIP strip along the bottom (mirrors the sharer's view).
    if (showRemoteTile) {
      return _buildRemoteSharingLayout(
        remoteParticipants,
        remoteShareTrack: remoteShareTrack,
        remoteSharerName: remoteSharerName,
        remoteSharerUserId: remoteSharerUserId,
        remoteSharerHasAudio: remoteSharerHasAudio,
        isMutedLocally: isMutedLocally,
      );
    }

    final all = <Widget>[];

    for (int i = 0; i < remoteParticipants.length; i++) {
      all.add(_buildRemoteTile(remoteParticipants[i], i));
    }

    final count = all.length;
    if (count == 1) return all.first;
    // Local is a floating PIP now, so 2 remotes split the screen equally
    // instead of the old fullscreen + corner (P2P) layout.
    if (count == 2) return _buildTwoSplitLayout(all);
    if (count == 3) return _buildTriSplitLayout(all);
    if (count == 4) return _buildGrid2x2Layout(all);
    if (count == 5) return _buildGrid5Layout(all);
    if (count == 6) return _buildGrid3x2Layout(all);
    
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.8,
      ),
      itemCount: all.length,
      itemBuilder: (context, i) => all[i],
    );
  }

  // Two remotes split the screen equally (top / bottom).
  Widget _buildTwoSplitLayout(List<Widget> tiles) {
    return Column(
      children: [
        Expanded(child: tiles[0]),
        Expanded(child: tiles[1]),
      ],
    );
  }

  /// Viewer's layout while a remote participant is sharing: their shared screen
  /// fills the top (pinch-to-zoom via ScreenShareTile) and everyone else shows
  /// as a PIP strip along the bottom.
  Widget _buildRemoteSharingLayout(
    List<RemoteParticipant> remotes, {
    required VideoTrack? remoteShareTrack,
    required String remoteSharerName,
    required String remoteSharerUserId,
    required bool remoteSharerHasAudio,
    required bool isMutedLocally,
  }) {
    return Column(
      children: [
        Expanded(
          child: ScreenShareTile(
            videoTrack: remoteShareTrack,
            participantName: remoteSharerName,
            hasAudio: remoteSharerHasAudio,
            isMutedLocally: isMutedLocally,
            onMuteToggle: () => context
                .read<CallCubit>()
                .toggleReceivedScreenShareAudioMute(remoteSharerUserId),
          ),
        ),
        if (remotes.isNotEmpty)
          SizedBox(
            height: 170.resH,
            child: Padding(
              padding: EdgeInsets.all(6.resR),
              child: Row(
                children: [
                  for (int i = 0; i < remotes.length && i < 4; i++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4.resR),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16.resR),
                          child: _buildRemoteTile(remotes[i], i),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// The local sharer's layout: a "You're sharing your screen!" panel with the
  /// other participants as a strip of PIPs along the bottom (matches the design).
  Widget _buildLocalSharingLayout(List<RemoteParticipant> remotes) {
    return Column(
      children: [
        Expanded(child: _buildLocalSharingView()),
        if (remotes.isNotEmpty)
          SizedBox(
            height: 170.resH,
            child: Padding(
              padding: EdgeInsets.all(6.resR),
              child: Row(
                children: [
                  for (int i = 0; i < remotes.length && i < 4; i++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4.resR),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16.resR),
                          child: _buildRemoteTile(remotes[i], i),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLocalSharingView() {
    return Container(
      decoration: const BoxDecoration(color: Color(0xFF1A1A2E)),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.screen_share, size: 72.resR, color: Colors.white),
            SizedBox(height: 16.resH),
            Text(
              "You're sharing your screen!",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.resSp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 20.resH),
            GestureDetector(
              onTap: () => context.read<CallCubit>().stopScreenShare(
                    localUserId: _localUserId,
                    localUserName: _localUserName,
                  ),
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: 22.resW, vertical: 12.resH),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(24.resR),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 24.resR,
                      height: 24.resR,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close,
                          size: 16.resR, color: Colors.black),
                    ),
                    SizedBox(width: 10.resW),
                    Text(
                      'Stop Sharing',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.resSp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTriSplitLayout(List<Widget> tiles) {
    return Column(
      children: [
        Expanded(child: tiles[0]),
        Expanded(
          child: Row(
            children: [
              Expanded(child: tiles[1]),
              Expanded(child: tiles[2]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGrid2x2Layout(List<Widget> tiles) {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: tiles[0]),
              Expanded(child: tiles[1]),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(child: tiles[2]),
              Expanded(child: tiles[3]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGrid5Layout(List<Widget> tiles) {
    return Column(
      children: [
        Expanded(child: tiles[0]),
        Expanded(
          child: Row(
            children: [
              Expanded(child: tiles[1]),
              Expanded(child: tiles[2]),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(child: tiles[3]),
              Expanded(child: tiles[4]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGrid3x2Layout(List<Widget> tiles) {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: tiles[0]),
              Expanded(child: tiles[1]),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(child: tiles[2]),
              Expanded(child: tiles[3]),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(child: tiles[4]),
              Expanded(child: tiles[5]),
            ],
          ),
        ),
      ],
    );
  }

  // ── Tiles ──────────────────────────────────────────────────────────────────

  Widget _buildLocalTile() {
    final displayName = _localUserName.isNotEmpty ? _localUserName : 'You';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'Y';

    return _ParticipantTile(
      initial: initial,
      label: 'call_you'.tr(),
      color: _kTileColors[4], // teal
      isMuted: _isMicMuted,
      videoTrack: (!_isCameraDisabled && _room != null)
          ? _room?.localParticipant?.videoTrackPublications
                .where(
                  (pub) =>
                      pub.source == TrackSource.camera &&
                      pub.track is VideoTrack &&
                      !pub.muted,
                )
                .map((pub) => pub.track as VideoTrack)
                .firstOrNull
          : null,
    );
  }

  Widget _buildRemoteTile(RemoteParticipant participant, int index) {
    final videoTrack = participant.videoTrackPublications
        .where(
          (pub) =>
              pub.source == TrackSource.camera &&
              pub.track is VideoTrack &&
              !pub.muted,
        )
        .map((pub) => pub.track as VideoTrack)
        .firstOrNull;

    final displayName = participant.name.isNotEmpty
        ? participant.name
        : participant.identity;
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';
    final isMuted = participant.audioTrackPublications.any(
      (pub) => pub.muted || pub.track == null,
    );
    final speakerId = participant.identity;

    return BlocBuilder<TranslationCubit, TranslationState>(
      bloc: _translationCubit,
      builder: (context, translationState) {
        final sub = translationState.subscriptions[speakerId];
        return _ParticipantTile(
          initial: initial,
          label: displayName,
          color:
              _kTileColors[index % (_kTileColors.length - 1)], // exclude teal
          isMuted: isMuted,
          videoTrack: videoTrack,
          caption: _translationCubit.captionNotifier(speakerId),
          translationStatus: sub?.status ?? TranslationStatus.off,
          onTapTranslate: () => _onTapTranslate(speakerId, sub),
        );
      },
    );
  }

  /// T025/T027 (US3): shows [TranslationToggleSheet] for [speakerId] and
  /// dispatches subscribe/unsubscribe/changeLanguage based on the result.
  Future<void> _onTapTranslate(
    String speakerId,
    TranslationSubscription? sub,
  ) async {
    final isEnabled = sub != null && sub.status != TranslationStatus.off;
    final initialLanguage = _translationCubit.resolveTargetLanguage(
      speakerId,
      deviceLanguageCode: context.locale.languageCode,
      supportedLanguages: kSupportedTranslationLanguages,
    );

    final result = await showModalBottomSheet<TranslationToggleResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => TranslationToggleSheet(
        isEnabled: isEnabled,
        initialLanguage: initialLanguage,
      ),
    );
    if (result == null || !mounted) return;

    switch (result) {
      case TranslationToggleOn(targetLanguage: final targetLanguage):
        if (!isEnabled) {
          debugPrint(
            '[GroupCallScreen] CC → subscribe(speakerId: $speakerId, targetLanguage: $targetLanguage)',
          );
          _translationCubit.subscribe(
            speakerId: speakerId,
            targetLanguage: targetLanguage,
          );
        } else if (sub.targetLanguage != targetLanguage) {
          debugPrint(
            '[GroupCallScreen] CC → changeLanguage(speakerId: $speakerId, targetLanguage: $targetLanguage)',
          );
          _translationCubit.changeLanguage(
            speakerId: speakerId,
            targetLanguage: targetLanguage,
          );
        } else {
          debugPrint(
            '[GroupCallScreen] CC → already enabled with same language ($targetLanguage), no-op.',
          );
        }
      case TranslationToggleOff():
        if (isEnabled) {
          debugPrint(
            '[GroupCallScreen] CC → unsubscribe(speakerId: $speakerId)',
          );
          _translationCubit.unsubscribe(speakerId);
        }
    }
  }

  // ── Controls ───────────────────────────────────────────────────────────────

  Widget _buildControls({required bool isSharing}) {
    // Same bottom bar as the 1:1 video screen: camera · flip · mic · emoji · ≡.
    // (Speaker + End live in the top bar.)
    return Padding(
      padding: EdgeInsets.only(bottom: 24.resH, left: 16.resW, right: 16.resW, top: 8.resH),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildIconBtn2(
                  icon: _isCameraDisabled ? Icons.videocam_off : Icons.videocam_outlined,
                  isActive: _isCameraDisabled,
                  onTap: () async {
                    final target = _isCameraDisabled;
                    if (target) {
                      final granted = await PermissionService.requestSingle(Permission.camera);
                      if (!granted && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Camera permission required.')));
                        return;
                      }
                    }
                    setState(() => _isCameraDisabled = !target);
                    await _room?.localParticipant?.setCameraEnabled(target);
                  },
                ),
                _buildIconBtn2(
                  icon: Icons.cameraswitch_outlined,
                  isActive: false,
                  onTap: () async {
                    try {
                      final track = _room?.localParticipant?.videoTrackPublications.firstOrNull?.track;
                      if (track is LocalVideoTrack) {
                        _isFrontCamera = !_isFrontCamera;
                        final options = CameraCaptureOptions(cameraPosition: _isFrontCamera ? CameraPosition.front : CameraPosition.back);
                        await track.restartTrack(options);
                        setState(() {});
                      }
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                    }
                  },
                ),
                _buildIconBtn2(
                  icon: _isMicMuted ? Icons.mic_off : Icons.mic_none,
                  isActive: _isMicMuted,
                  onTap: () async {
                    final targetMuted = !_isMicMuted;
                    setState(() => _isMicMuted = targetMuted);
                    await _room?.localParticipant?.setMicrophoneEnabled(!targetMuted);
                    if (mounted) context.read<CallCubit>().reportLocalMute(targetMuted);
                  },
                ),
                _buildIconBtn2(
                  icon: Icons.emoji_emotions_outlined,
                  isActive: _isEmojiOpen,
                  onTap: () => setState(() => _isEmojiOpen = !_isEmojiOpen),
                ),
                _buildIconBtn2(
                  icon: Icons.menu,
                  isActive: false,
                  onTap: () => _showMoreOptions(isSharing: isSharing),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The ≡ More menu — Share Screen only. Translation is handled per-participant
  /// via the CC control on each tile, so it's omitted here.
  void _showMoreOptions({required bool isSharing}) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => CallMoreOptionsSheet(
        title: _groupName.isNotEmpty ? _groupName : 'Group Call',
        isSharing: isSharing,
        isTranslating: false,
        onShareScreen: () {
          Navigator.pop(sheetCtx);
          if (!mounted) return;
          final cubit = context.read<CallCubit>();
          final s = cubit.state;
          if (isSharing) {
            cubit.stopScreenShare(
              localUserId: _localUserId,
              localUserName: _localUserName,
            );
            return;
          }
          // Only one participant may share at a time.
          if (s is CallActive &&
              s.activeSharerUserId.isNotEmpty &&
              s.activeSharerUserId != _localUserId) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${s.activeSharerName} is already sharing')),
            );
            return;
          }
          // Start immediately, no audio (no toggle sheet).
          cubit.startScreenShare(
            localUserId: _localUserId,
            localUserName: _localUserName,
            withDeviceAudio: false,
          );
        },
      ),
    );
  }

  Widget _buildIconBtn2({required IconData icon, required VoidCallback onTap, bool isActive = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52.resR,
        height: 52.resR,
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withOpacity(0.4) : Colors.white.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 24.resR),
      ),
    );
  }

}


// ─────────────────────────────────────────────────────────────────────────────
// Participant Tile
// ─────────────────────────────────────────────────────────────────────────────

class _ParticipantTile extends StatelessWidget {
  final String initial;
  final String label;
  final Color color;
  final bool isMuted;
  final VideoTrack? videoTrack;

  /// FR-004 (T019): per-speaker live caption, rendered via [CaptionOverlay].
  final ValueListenable<Caption?>? caption;

  /// US3 (T027/T028): this speaker's translation toggle status, drives the
  /// CC icon highlight and the "translation unavailable" badge.
  final TranslationStatus? translationStatus;

  /// US3 (T027): tapped to open [TranslationToggleSheet] for this speaker.
  /// `null` (e.g. the local tile) hides the CC icon entirely.
  final VoidCallback? onTapTranslate;

  const _ParticipantTile({
    required this.initial,
    required this.label,
    required this.color,
    required this.isMuted,
    this.videoTrack,
    this.caption,
    this.translationStatus,
    this.onTapTranslate,
  });

  @override
  Widget build(BuildContext context) {
    final isTranslationLive =
        translationStatus == TranslationStatus.pending ||
        translationStatus == TranslationStatus.active;

    return Container(
      decoration: BoxDecoration(color: color),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        fit: StackFit.expand,
            children: [
              // Avatar letter + name
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 44,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),

              // Video overlay (if camera is on) — fill the whole tile.
              if (videoTrack != null)
                Positioned.fill(
                  child: VideoTrackRenderer(
                    videoTrack!,
                    fit: VideoViewFit.cover,
                  ),
                ),

              // Muted badge (top-right)
              if (isMuted)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.mic_off,
                      size: 16,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),

              // CC (translation) toggle — bottom-left, clear of the status bar
              // and the floating top bar (better UX than the previous top-left).
              if (onTapTranslate != null)
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: GestureDetector(
                    onTap: onTapTranslate,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isTranslationLive
                            ? _kGreen
                            : Colors.black.withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.closed_caption,
                        size: 22,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

              // "Translation unavailable" badge (FR-002/FR-014)
              if (translationStatus == TranslationStatus.unavailable)
                Positioned(
                  bottom: 60,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'translation_unavailable_badge'.tr(),
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),

              // Live translation caption (FR-004/FR-009/FR-011) — above the CC.
              if (caption != null)
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 62,
                  child: CaptionOverlay(caption: caption!),
                ),
            ],
          ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REC Banner
// ─────────────────────────────────────────────────────────────────────────────

class _RecordingBanner extends StatelessWidget {
  const _RecordingBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fiber_manual_record, color: Colors.white, size: 10),
          SizedBox(width: 4),
          Text(
            'REC',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
