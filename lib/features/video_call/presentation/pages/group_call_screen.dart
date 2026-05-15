import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';
import '../bloc/call_cubit.dart';
import '../../../call_recording/presentation/bloc/call_recording_cubit.dart';

/// Full-screen group video/voice call screen backed by LiveKit.
/// The roomId comes from the route; LiveKit credentials come from CallActive state.
class GroupCallScreen extends StatefulWidget {
  final String roomId;

  const GroupCallScreen({super.key, required this.roomId});

  @override
  State<GroupCallScreen> createState() => _GroupCallScreenState();
}

class _GroupCallScreenState extends State<GroupCallScreen> {
  Room? _room;
  bool _isConnecting = true;
  bool _isMicMuted = false;
  bool _isCameraDisabled = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _connectFromCubitState());
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

  Future<void> _connectToRoom(String url, String token, {bool isVideo = true}) async {
    try {
      _room = Room();
      _room!.addListener(_onRoomUpdate);
      await _room!.connect(url, token);
      await _room!.localParticipant?.setCameraEnabled(isVideo);
      await _room!.localParticipant?.setMicrophoneEnabled(true);
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _isCameraDisabled = !isVideo;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _error = e.toString(); _isConnecting = false; });
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
    // T078: auto-stop recording when call ends
    if (recCubit.state is RecordingActive) {
      await recCubit.stop();
    }
    callCubit.leaveGroupCall();
    await _room?.disconnect();
    if (mounted) {
      if (canPop) {
        router.pop();
      } else {
        router.go('/home');
      }
    }
  }

  @override
  void dispose() {
    _room?.removeListener(_onRoomUpdate);
    _room?.disconnect();
    super.dispose();
  }

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
        backgroundColor: Colors.black,
        body: SafeArea(
          child: _isConnecting
              ? _buildConnecting()
              : _error != null
                  ? _buildError()
                  : _buildCallBody(),
        ),
      ),
    );
  }

  Widget _buildConnecting() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text('Joining group call…', style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
      ),
    );
  }

  Widget _buildCallBody() {
    return BlocBuilder<CallCubit, CallState>(
      builder: (context, state) {
        final isRecording = state is CallActive && state.isGroupCall && state.recordingState.isRecording;
        final remoteParticipants = _room?.remoteParticipants.values.toList() ?? [];

        return Stack(
          children: [
            _buildParticipantGrid(remoteParticipants),

            // Recordings fast-access button (T076)
            Positioned(
              top: 8.resH,
              right: 12.resW,
              child: GestureDetector(
                onTap: () => context.push('/recordings'),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.resW, vertical: 6.resH),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(16.resR),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.folder_outlined, color: Colors.white, size: 16.resW),
                      SizedBox(width: 4.resW),
                      Text('Recordings', style: TextStyle(color: Colors.white, fontSize: 12.resSp)),
                    ],
                  ),
                ),
              ),
            ),

            // T064 — REC banner
            if (isRecording)
              Positioned(
                top: 12.resH,
                left: 0,
                right: 0,
                child: const Center(child: _RecordingBanner()),
              ),

            Positioned(
              left: 0,
              right: 0,
              bottom: 32.resH,
              child: _buildControls(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildParticipantGrid(List<RemoteParticipant> remoteParticipants) {
    final total = remoteParticipants.length + 1; // +1 for local

    if (total <= 2) {
      return Column(
        children: [
          Expanded(child: _buildLocalTile()),
          if (remoteParticipants.isNotEmpty)
            Expanded(child: _buildRemoteTile(remoteParticipants.first)),
        ],
      );
    }

    return GridView.builder(
      padding: EdgeInsets.only(bottom: 110.resH),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: total,
      itemBuilder: (context, i) {
        if (i == 0) return _buildLocalTile();
        return _buildRemoteTile(remoteParticipants[i - 1]);
      },
    );
  }

  Widget _buildLocalTile() {
    return Container(
      color: const Color(0xFF1A1A2E),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (!_isCameraDisabled)
            _LocalVideoWidget(room: _room)
          else
            const Center(child: Icon(Icons.person, color: Colors.white54, size: 48)),
          const Positioned(
            bottom: 8,
            left: 8,
            child: Text('You', style: TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildRemoteTile(RemoteParticipant participant) {
    final videoTrack = participant.videoTrackPublications
        .where((pub) => pub.track is VideoTrack && !pub.muted)
        .map((pub) => pub.track as VideoTrack)
        .firstOrNull;

    return Container(
      color: const Color(0xFF2D2D44),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (videoTrack != null)
            VideoTrackRenderer(videoTrack)
          else
            const Center(child: Icon(Icons.person, color: Colors.white54, size: 48)),
          Positioned(
            bottom: 8,
            left: 8,
            child: Text(
              participant.identity,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return BlocBuilder<CallRecordingCubit, CallRecordingState>(
      builder: (context, recordingState) {
        final isRecording = recordingState is RecordingActive;
        final callState = context.read<CallCubit>().state;
        final roomName = callState is CallActive ? callState.contactName : '';

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _ControlButton(
              icon: _isMicMuted ? Icons.mic_off : Icons.mic,
              onTap: () async {
                setState(() => _isMicMuted = !_isMicMuted);
                await _room?.localParticipant?.setMicrophoneEnabled(!_isMicMuted);
              },
            ),
            _ControlButton(
              icon: isRecording ? Icons.stop_circle_outlined : Icons.fiber_manual_record,
              color: isRecording ? const Color(0xFFE53935) : const Color(0xFF444444),
              onTap: () {
                if (isRecording) {
                  context.read<CallRecordingCubit>().stop(callRoomName: roomName);
                } else {
                  context.read<CallRecordingCubit>().start(
                    callRoomId: widget.roomId,
                    callRoomName: roomName,
                  );
                }
              },
            ),
            _ControlButton(
              icon: Icons.call_end,
              color: const Color(0xFFE53935),
              onTap: _endCall,
              size: 64,
            ),
            _ControlButton(
              icon: _isCameraDisabled ? Icons.videocam_off : Icons.videocam,
              onTap: () async {
                setState(() => _isCameraDisabled = !_isCameraDisabled);
                await _room?.localParticipant?.setCameraEnabled(!_isCameraDisabled);
              },
            ),
          ],
        );
      },
    );
  }
}

// ── Local video widget ───────────────────────────────────────────────────────

class _LocalVideoWidget extends StatelessWidget {
  final Room? room;
  const _LocalVideoWidget({required this.room});

  @override
  Widget build(BuildContext context) {
    final track = room?.localParticipant?.videoTrackPublications
        .where((pub) => pub.track is VideoTrack && !pub.muted)
        .map((pub) => pub.track as VideoTrack)
        .firstOrNull;
    if (track == null) return const SizedBox.shrink();
    return VideoTrackRenderer(track);
  }
}

// ── Control button ───────────────────────────────────────────────────────────

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double size;

  const _ControlButton({
    required this.icon,
    this.color = const Color(0xFF444444),
    required this.onTap,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size.resW,
        height: size.resW,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: (size * 0.5).resW),
      ),
    );
  }
}

// ── T064: REC banner ─────────────────────────────────────────────────────────

class _RecordingBanner extends StatelessWidget {
  const _RecordingBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fiber_manual_record, color: Colors.white, size: 12),
          SizedBox(width: 6),
          Text('REC', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
