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
import '../widgets/screen_share_toggle_sheet.dart';
import '../../../call_recording/presentation/bloc/call_recording_cubit.dart';
import '../../../translation/domain/entities/caption.dart';
import '../../../translation/domain/entities/supported_languages.dart';
import '../../../translation/domain/entities/translation_subscription.dart';
import '../../../translation/presentation/bloc/translation_cubit.dart';
import '../../../translation/presentation/bloc/translation_state.dart';
import '../../../translation/presentation/widgets/caption_overlay.dart';
import '../../../translation/presentation/widgets/subtitle_overlay_widget.dart';
import '../../../translation/presentation/widgets/translation_toggle_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Palette (matches the mockup exactly)
// ─────────────────────────────────────────────────────────────────────────────
const _kBg = Color(0xFF616161); // dark gray background
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
  const GroupCallScreen({super.key, required this.roomId});

  @override
  State<GroupCallScreen> createState() => _GroupCallScreenState();
}

class _GroupCallScreenState extends State<GroupCallScreen> {
  Room? _room;
  EventsListener<RoomEvent>? _roomEventsListener;
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

  // Timer
  late final Stopwatch _callTimer;
  Timer? _uiTimer;

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
    _callTimer = Stopwatch()..start();
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

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
  }) async {
    try {
      await PermissionService.requestSingle(Permission.microphone);
      if (isVideo) await PermissionService.requestSingle(Permission.camera);

      // Configure the OS voice-communication audio session BEFORE connecting
      // (FR-Audio-01, SC-003).
      await getIt<CallAudioSessionService>().configureForCall();

      _room = Room(roomOptions: CallAudioConfig.roomOptions());
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

      await _room!.connect(url, token);
      debugPrint(
        '[GroupCallScreen] Room connected. Calling attachRoom with roomId: $chatRoomId',
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
      await _room!.localParticipant?.setCameraEnabled(isVideo);
      await _room!.localParticipant?.setMicrophoneEnabled(true);
      if (isVideo) await _room!.localParticipant?.setCameraEnabled(true);

      // Default audio route: BT takes precedence, else video→speaker /
      // voice→earpiece (FR-VoIP-10). Output-only — never touches the 019
      // audio session configured above.
      _routeSub = _audioRoute.routeStream.listen((s) {
        if (mounted) setState(() => _routeState = s);
      });
      await _audioRoute.start();
      await _audioRoute.applyDefaultForCall(isVideo: isVideo);

      if (mounted) {
        setState(() {
          _isConnecting = false;
          _isCameraDisabled = !isVideo;
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
    await _room?.disconnect();
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
    _callTimer.stop();
    _sideEventSub?.cancel();
    _callStateSub?.cancel();
    _routeSub?.cancel();
    _roomEventsListener?.dispose();
    _rawDataDebugSub?.call();
    _translationCubit.detachRoom();
    _translationCubit.close();
    getIt<VideoCallRepository>().setCallServiceActive(false);
    getIt<VideoCallRepository>().setExternalRoom(null);
    _room?.removeListener(_onRoomUpdate);
    _room?.disconnect();
    getIt<CallAudioSessionService>().deactivate();
    _audioRoute.stop();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String get _elapsedLabel {
    final s = _callTimer.elapsed;
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
                _room?.disconnect().then((_) {
                  if (!mounted) return;
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
                });
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
          backgroundColor: _kBg,
          body: SafeArea(
            bottom: false,
            child: _isConnecting
                ? _buildConnecting()
                : _error != null
                ? _buildError()
                : _buildCallBody(),
          ),
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
        final groupName = callActive ? (state.chatRoomId) : widget.roomId;

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

        return Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            _buildHeader(
              groupName: groupName,
              isWaiting: isWaiting,
              participantCount: participantCount,
              isRecording: isRecording,
              isSharing: isSharing,
            ),

            // ── Content area + subtitle overlay ───────────────────────────
            Expanded(
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
                  // FR-004/FR-010: unified subtitle strip at the bottom of the
                  // grid — visible regardless of tile size or camera state.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: SubtitleOverlayWidget(
                      transcript: _translationCubit.transcriptList,
                      participants: remoteParticipants,
                    ),
                  ),
                ],
              ),
            ),

            // ── Controls ─────────────────────────────────────────────────────
            _buildControls(isSharing: isSharing),
          ],
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
    return Padding(
      padding: EdgeInsets.only(
        top: 24.resH,
        bottom: 12.resH,
        left: 16.resW,
        right: 16.resW,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                groupName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 4.resH),
              if (isWaiting)
                Text(
                  'call_waiting_to_join'.tr(),
                  style: const TextStyle(
                    color: Color(0xFFCCCCCC),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                )
              else ...[
                Text(
                  _elapsedLabel,
                  style: const TextStyle(
                    color: Color(0xFFCCCCCC),
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 2.resH),
                Text(
                  'call_participants_count'.tr(
                    namedArgs: {'count': '$participantCount'},
                  ),
                  style: const TextStyle(
                    color: Color(0xFFCCCCCC),
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
          // REC badge (top-right)
          if (isRecording)
            Positioned(right: 0, top: 0, child: const _RecordingBanner()),
          // Screen-share banner
          if (isSharing)
            Positioned(
              right: 0,
              top: 0,
              child: GestureDetector(
                onTap: () => context.read<CallCubit>().stopScreenShare(
                  localUserId: _localUserId,
                  localUserName: _localUserName,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade700,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.stop_screen_share,
                        color: Colors.white,
                        size: 14,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Stop',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
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
    final remoteShareExtra = showRemoteTile ? 1 : 0;
    final localShareExtra = isSharing ? 1 : 0;
    final total =
        remoteParticipants.length + 1 + remoteShareExtra + localShareExtra;

    if (total <= 5) {
      return _buildCompactGrid(
        remoteParticipants,
        showRemoteTile: showRemoteTile,
        remoteShareTrack: remoteShareTrack,
        remoteSharerName: remoteSharerName,
        remoteSharerUserId: remoteSharerUserId,
        remoteSharerHasAudio: remoteSharerHasAudio,
        isMutedLocally: isMutedLocally,
        isSharing: isSharing,
        localShareTrack: localShareTrack,
      );
    }
    return _buildScrollableGrid(
      remoteParticipants,
      showRemoteTile: showRemoteTile,
      remoteShareTrack: remoteShareTrack,
      remoteSharerName: remoteSharerName,
      remoteSharerUserId: remoteSharerUserId,
      remoteSharerHasAudio: remoteSharerHasAudio,
      isMutedLocally: isMutedLocally,
      isSharing: isSharing,
      localShareTrack: localShareTrack,
    );
  }

  /// 2-column grid with special centering for odd last tile (≤5 participants)
  Widget _buildCompactGrid(
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
    final all = <Widget>[
      for (int i = 0; i < remoteParticipants.length; i++)
        _buildRemoteTile(remoteParticipants[i], i),
      _buildLocalTile(),
      if (showRemoteTile)
        ScreenShareTile(
          videoTrack: remoteShareTrack,
          participantName: remoteSharerName,
          hasAudio: remoteSharerHasAudio,
          isMutedLocally: isMutedLocally,
          onMuteToggle: () => context
              .read<CallCubit>()
              .toggleReceivedScreenShareAudioMute(remoteSharerUserId),
        ),
      if (isSharing) _LocalShareTile(localShareTrack: localShareTrack),
    ];

    // Build rows of 2; last item centered if alone
    final rows = <Widget>[];
    for (int i = 0; i < all.length; i += 2) {
      if (i + 1 < all.length) {
        rows.add(
          Row(
            children: [
              Expanded(child: all[i]),
              SizedBox(width: 10.resW),
              Expanded(child: all[i + 1]),
            ],
          ),
        );
      } else {
        // Last lone tile: center it, half width
        rows.add(
          Row(
            children: [
              const Spacer(),
              Expanded(flex: 2, child: all[i]),
              const Spacer(),
            ],
          ),
        );
      }
      if (i + 2 < all.length) rows.add(SizedBox(height: 10.resH));
    }

    // Wrap in a SingleChildScrollView so adding the screen-share tile (which
    // pushes total height past the available space by ~10–20px on some
    // devices) doesn't produce a yellow overflow stripe.
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 10.resW, vertical: 8.resH),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: rows,
      ),
    );
  }

  /// Standard 2-column scrollable grid (6+ participants)
  Widget _buildScrollableGrid(
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
    final remoteShareExtra = showRemoteTile ? 1 : 0;
    final localShareExtra = isSharing ? 1 : 0;
    final total =
        remoteParticipants.length + 1 + remoteShareExtra + localShareExtra;

    return GridView.builder(
      padding: EdgeInsets.symmetric(horizontal: 10.resW, vertical: 8.resH),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.9,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: total,
      itemBuilder: (context, i) {
        // Order: remote cameras → local camera → remote share → local share.
        if (i < remoteParticipants.length) {
          return _buildRemoteTile(remoteParticipants[i], i);
        }
        var idx =
            i - remoteParticipants.length; // 0..(1+remoteShare+localShare-1)
        if (idx == 0) return _buildLocalTile();
        idx -= 1;
        if (showRemoteTile && idx == 0) {
          return ScreenShareTile(
            videoTrack: remoteShareTrack,
            participantName: remoteSharerName,
            hasAudio: remoteSharerHasAudio,
            isMutedLocally: isMutedLocally,
            onMuteToggle: () => context
                .read<CallCubit>()
                .toggleReceivedScreenShareAudioMute(remoteSharerUserId),
          );
        }
        if (showRemoteTile) idx -= 1;
        if (isSharing && idx == 0) {
          return _LocalShareTile(localShareTrack: localShareTrack);
        }
        return const SizedBox.shrink();
      },
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
    return Container(
      padding: EdgeInsets.only(
        top: 16.resH,
        bottom: 28.resH,
        left: 20.resW,
        right: 20.resW,
      ),
      decoration: const BoxDecoration(
        color: _kControlsBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ────────────────────────────────────────────────
          Container(
            width: 40.resW,
            height: 4.resH,
            margin: EdgeInsets.only(bottom: 16.resH),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // ── 5 icon buttons row (matches screenshot) ─────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Camera toggle
              _buildIconBtn(
                icon: _isCameraDisabled
                    ? Icons.videocam_off
                    : Icons.videocam_outlined,
                label: 'call_btn_video'.tr(),
                active: !_isCameraDisabled,
                onTap: () async {
                  final target = _isCameraDisabled;
                  if (target) {
                    final granted = await PermissionService.requestSingle(
                      Permission.camera,
                    );
                    if (!granted && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Camera permission is required.'),
                        ),
                      );
                      return;
                    }
                  }
                  setState(() => _isCameraDisabled = !target);
                  await _room?.localParticipant?.setCameraEnabled(target);
                },
              ),
              // Flip / Toggle Views
              _buildIconBtn(
                icon: Icons.flip_camera_android_outlined,
                label: 'Toggle',
                active: false,
                onTap: () async {
                  try {
                    final track = _room
                        ?.localParticipant
                        ?.videoTrackPublications
                        .firstOrNull
                        ?.track;
                    if (track is LocalVideoTrack) {
                      _isFrontCamera = !_isFrontCamera;
                      final options = CameraCaptureOptions(
                        cameraPosition: _isFrontCamera
                            ? CameraPosition.front
                            : CameraPosition.back,
                      );
                      await track.restartTrack(options);
                      setState(() {});
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to switch camera: $e')),
                      );
                    }
                  }
                },
              ),
              // Mic toggle
              _buildIconBtn(
                icon: _isMicMuted ? Icons.mic_off : Icons.mic_none,
                label: _isMicMuted
                    ? 'call_btn_muted'.tr()
                    : 'call_btn_mute'.tr(),
                active: false,
                onTap: () async {
                  final targetMuted = !_isMicMuted;
                  setState(() => _isMicMuted = targetMuted);
                  await _room?.localParticipant?.setMicrophoneEnabled(
                    !targetMuted,
                  );
                  if (mounted) context.read<CallCubit>().reportLocalMute(targetMuted);
                },
              ),
              // Audio route — opens Earpiece/Speaker/Bluetooth picker
              // (FR-VoIP-07); icon reflects the active route (FR-VoIP-08).
              _buildIconBtn(
                icon: speakerIconForRoute(_routeState.activeRoute),
                label: 'call_btn_speaker'.tr(),
                active: _routeState.activeRoute != AudioOutputRoute.earpiece,
                onTap: () => AudioRoutePickerSheet.show(context),
              ),
              // More options ≡
              _buildIconBtn(
                icon: Icons.menu,
                label: 'More',
                active: false,
                onTap: () => _showMoreOptions(isSharing: isSharing),
              ),
            ],
          ),

          SizedBox(height: 20.resH),

          // ── End Call button ──────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                padding: EdgeInsets.symmetric(vertical: 14.resH),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _endCall,
              icon: const Icon(Icons.call_end, color: Colors.white),
              label: Text(
                'call_action_end'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Shows the More Options bottom sheet matching the screenshot design
  void _showMoreOptions({required bool isSharing}) {
    final roomId = widget.roomId;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => _MoreOptionsSheet(
        roomId: roomId,
        isSharing: isSharing,
        onShareScreen: () async {
          Navigator.pop(sheetCtx);
          if (isSharing) {
            if (mounted) {
              context.read<CallCubit>().stopScreenShare(
                localUserId: _localUserId,
                localUserName: _localUserName,
              );
            }
          } else {
            final withAudio = await showModalBottomSheet<bool>(
              context: context,
              builder: (_) => const ScreenShareToggleSheet(),
            );
            if (withAudio != null && mounted) {
              context.read<CallCubit>().startScreenShare(
                localUserId: _localUserId,
                localUserName: _localUserName,
                withDeviceAudio: withAudio,
              );
            }
          }
        },
      ),
    );
  }

  Widget _buildIconBtn({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52.resW,
            height: 52.resW,
            decoration: BoxDecoration(
              color: active ? Colors.white : _kBtnGray,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: active ? _kGreen : Colors.white,
              size: 24.resW,
            ),
          ),
          SizedBox(height: 6.resH),
          Text(
            label,
            style: TextStyle(color: Colors.white70, fontSize: 11.resSp),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// More Options Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _MoreOptionsSheet extends StatelessWidget {
  final String roomId;
  final bool isSharing;
  final VoidCallback onShareScreen;

  const _MoreOptionsSheet({
    required this.roomId,
    required this.isSharing,
    required this.onShareScreen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF2A2A3E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Handle ──────────────────────────────────────────────────────
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // ── Header row ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.view_column_outlined,
                    color: Colors.white70,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Call with $roomId',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white70,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Share Screen button ─────────────────────────────────────────
            _MoreOptionsTile(
              icon: Icons.ios_share,
              label: isSharing ? 'Stop Sharing' : 'Share Screen',
              onTap: onShareScreen,
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _MoreOptionsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MoreOptionsTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF3D3D55),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 22),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
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

    return AspectRatio(
      aspectRatio: 0.9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          color: color,
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

              // Video overlay (if camera is on)
              if (videoTrack != null)
                Positioned.fill(child: VideoTrackRenderer(videoTrack!)),

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

              // CC (translation) toggle (top-left)
              if (onTapTranslate != null)
                Positioned(
                  top: 10,
                  left: 10,
                  child: GestureDetector(
                    onTap: onTapTranslate,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isTranslationLive ? _kGreen : Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.closed_caption,
                        size: 16,
                        color: isTranslationLive
                            ? Colors.white
                            : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),

              // "Translation unavailable" badge (FR-002/FR-014)
              if (translationStatus == TranslationStatus.unavailable)
                Positioned(
                  top: 44,
                  left: 10,
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

              // Live translation caption (FR-004/FR-009/FR-011)
              if (caption != null)
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: CaptionOverlay(caption: caption!),
                ),
            ],
          ),
        ),
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

// ── Local screen-share preview tile ────────────────────────────────────────────
// Shown to the sharer themselves so they can confirm what's being broadcast.
// Renders the actual screen-share video track when published; otherwise a
// "Sharing your screen" placeholder while iOS / Android finishes publishing.
class _LocalShareTile extends StatelessWidget {
  final VideoTrack? localShareTrack;
  const _LocalShareTile({required this.localShareTrack});

  @override
  Widget build(BuildContext context) {
    // Match _ParticipantTile so the tile self-sizes when placed in a Row
    // inside _buildCompactGrid (which doesn't constrain height). Without
    // this AspectRatio, StackFit.expand below blows up with infinite height.
    return AspectRatio(
      aspectRatio: 0.9,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (localShareTrack != null)
              VideoTrackRenderer(localShareTrack!)
            else
              const ColoredBox(
                color: Colors.black87,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.screen_share, color: Colors.white, size: 36),
                      SizedBox(height: 8),
                      Text(
                        'Sharing\nyour screen',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.screen_share_outlined,
                      color: Colors.white70,
                      size: 14,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'You • Screen',
                      style: TextStyle(color: Colors.white, fontSize: 12),
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
}
