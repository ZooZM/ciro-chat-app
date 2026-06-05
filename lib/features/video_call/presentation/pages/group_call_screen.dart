import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:ciro_chat_app/core/di/injection.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ciro_chat_app/core/helpers/permission_service.dart';
import '../bloc/call_cubit.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../domain/repositories/video_call_repository.dart';
import '../widgets/screen_share_toggle_sheet.dart';
import '../../../call_recording/presentation/bloc/call_recording_cubit.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Palette (matches the mockup exactly)
// ─────────────────────────────────────────────────────────────────────────────
const _kBg = Color(0xFF616161); // dark gray background
const _kControlsBg = Color(0xFF3B3B3B); // controls panel
const _kGreen = Color(0xFF4CAF50);
const _kRed = Color(0xFFE53935);
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
  bool _isSpeakerOn = true; // speaker is on by default
  bool _isCameraDisabled = true; // voice call: camera off by default
  String? _error;

  // Screen-share side-events
  StreamSubscription<CallSideEvent>? _sideEventSub;
  StreamSubscription<CallState>? _callStateSub;
  String _localUserId = '';
  String _localUserName = '';
  String _prevSharerUserId = '';

  // Timer
  late final Stopwatch _callTimer;
  Timer? _uiTimer;

  @override
  void initState() {
    super.initState();
    _callTimer = Stopwatch()..start();
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    final authState = getIt<AuthCubit>().state;
    if (authState is Authenticated) {
      _localUserId = authState.userData?['id']?.toString() ?? '';
      _localUserName = authState.userData?['phoneNumber']?.toString() ?? '';
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
      _connectToRoom(s.livekitUrl, s.livekitToken, isVideo: s.isVideo);
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
  }) async {
    try {
      await PermissionService.requestSingle(Permission.microphone);
      if (isVideo) await PermissionService.requestSingle(Permission.camera);

      _room = Room(
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          defaultScreenShareCaptureOptions: ScreenShareCaptureOptions(
            useiOSBroadcastExtension: true,
          ),
        ),
      );
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
        });

      await _room!.connect(url, token);
      getIt<VideoCallRepository>().setExternalRoom(_room!);
      // Keep the WebRTC connection alive when the screen locks (Android).
      getIt<VideoCallRepository>().setCallServiceActive(true);
      await _room!.localParticipant?.setCameraEnabled(isVideo);
      await _room!.localParticipant?.setMicrophoneEnabled(true);
      if (isVideo) await _room!.localParticipant?.setCameraEnabled(true);

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
    _roomEventsListener?.dispose();
    getIt<VideoCallRepository>().setCallServiceActive(false);
    getIt<VideoCallRepository>().setExternalRoom(null);
    _room?.removeListener(_onRoomUpdate);
    _room?.disconnect();
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
    return BlocListener<CallCubit, CallState>(
      listener: (context, state) {
        if (state is CallIdle || state is CallEnded) {
          final router = GoRouter.of(context);
          final canPop = context.canPop();
          _room?.disconnect().then((_) {
            if (mounted) {
              if (canPop) {
                router.pop();
              } else {
                router.go('/home');
              }
            }
          });
        }
      },
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

            // ── Content area ─────────────────────────────────────────────────
            Expanded(
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
    final total = remoteParticipants.length + 1; // +1 local

    // ≤ 5 participants: 2-column grid, last item centered
    if (total <= 5) {
      return _buildCompactGrid(remoteParticipants);
    }

    // 6+ participants: standard 2-column scrollable grid
    return _buildScrollableGrid(remoteParticipants);
  }

  /// 2-column grid with special centering for odd last tile (≤5 participants)
  Widget _buildCompactGrid(List<RemoteParticipant> remoteParticipants) {
    final all = <Widget>[
      for (int i = 0; i < remoteParticipants.length; i++)
        _buildRemoteTile(remoteParticipants[i], i),
      _buildLocalTile(),
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

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10.resW, vertical: 8.resH),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: rows,
      ),
    );
  }

  /// Standard 2-column scrollable grid (6+ participants)
  Widget _buildScrollableGrid(List<RemoteParticipant> remoteParticipants) {
    return GridView.builder(
      padding: EdgeInsets.symmetric(horizontal: 10.resW, vertical: 8.resH),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.9,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: remoteParticipants.length + 1,
      itemBuilder: (context, i) {
        if (i < remoteParticipants.length) {
          return _buildRemoteTile(remoteParticipants[i], i);
        }
        return _buildLocalTile();
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

    return _ParticipantTile(
      initial: initial,
      label: displayName,
      color: _kTileColors[index % (_kTileColors.length - 1)], // exclude teal
      isMuted: isMuted,
      videoTrack: videoTrack,
    );
  }

  // ── Controls ───────────────────────────────────────────────────────────────

  Widget _buildControls({required bool isSharing}) {
    return Container(
      padding: EdgeInsets.only(
        top: 20.resH,
        bottom: 32.resH,
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
          // ── 4 primary action buttons ────────────────────────────────────
          Wrap(
            spacing: 12.resW,
            runSpacing: 16.resH,
            alignment: WrapAlignment.center,
            children: [
              // Mic toggle
              _buildIconBtn(
                icon: _isMicMuted ? Icons.mic_off : Icons.mic_none,
                label: _isMicMuted
                    ? 'call_btn_muted'.tr()
                    : 'call_btn_mute'.tr(),
                active: false,
                onTap: () async {
                  setState(() => _isMicMuted = !_isMicMuted);
                  await _room?.localParticipant?.setMicrophoneEnabled(
                    !_isMicMuted,
                  );
                },
              ),
              // Speaker toggle
              _buildIconBtn(
                icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                label: 'call_btn_speaker'.tr(),
                active: _isSpeakerOn,
                onTap: () => setState(() => _isSpeakerOn = !_isSpeakerOn),
              ),
              // Camera toggle
              _buildIconBtn(
                icon: _isCameraDisabled
                    ? Icons.videocam_off
                    : Icons.videocam_outlined,
                label: 'call_btn_video'.tr(),
                active: false,
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
              // Add participant
              _buildIconBtn(
                icon: Icons.person_add_outlined,
                label: 'call_btn_add'.tr(),
                active: false,
                onTap: () {}, // placeholder
              ),
              // Screen share
              _buildIconBtn(
                icon: isSharing ? Icons.stop_screen_share : Icons.screen_share,
                label: isSharing ? 'Stop Share' : 'Share',
                active: isSharing,
                onTap: () async {
                  if (isSharing) {
                    context.read<CallCubit>().stopScreenShare(
                      localUserId: _localUserId,
                      localUserName: _localUserName,
                    );
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
              // Record
              BlocBuilder<CallRecordingCubit, CallRecordingState>(
                builder: (context, recState) {
                  final isRecording = recState is RecordingActive;
                  return _buildIconBtn(
                    icon: isRecording
                        ? Icons.stop_circle
                        : Icons.radio_button_checked,
                    label: isRecording ? 'Stop Rec' : 'Record',
                    active: isRecording,
                    onTap: () {
                      if (isRecording) {
                        context.read<CallRecordingCubit>().stop(
                          callRoomName: widget.roomId,
                        );
                      } else {
                        context.read<CallRecordingCubit>().start(
                          callRoomId: widget.roomId,
                          callRoomName: widget.roomId,
                        );
                      }
                    },
                  );
                },
              ),
            ],
          ),

          SizedBox(height: 20.resH),

          // ── End Call button ──────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kRed,
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
// Participant Tile
// ─────────────────────────────────────────────────────────────────────────────

class _ParticipantTile extends StatelessWidget {
  final String initial;
  final String label;
  final Color color;
  final bool isMuted;
  final VideoTrack? videoTrack;

  const _ParticipantTile({
    required this.initial,
    required this.label,
    required this.color,
    required this.isMuted,
    this.videoTrack,
  });

  @override
  Widget build(BuildContext context) {
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
