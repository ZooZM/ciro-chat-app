import 'package:flutter/material.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:livekit_client/livekit_client.dart';

import '../bloc/video_call_cubit.dart';

class VideoCallScreen extends StatefulWidget {
  const VideoCallScreen({super.key});

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  bool _isMicMuted = false;
  bool _isCameraDisabled = false;

  @override
  void initState() {
    super.initState();
    // Start the connection process immediately
    context.read<VideoCallCubit>().joinRoom('testRoom1');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: BlocConsumer<VideoCallCubit, VideoCallState>(
        listener: (context, state) {
          if (state is VideoCallError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red),
            );
          }
        },
        builder: (context, state) {
          if (state is VideoCallInitial || state is VideoCallConnecting) {
            return _buildConnectingUI();
          } else if (state is VideoCallError) {
            return _buildErrorUI(state.message);
          } else if (state is VideoCallConnected) {
            return _buildConnectedUI(state.room);
          } else if (state is VideoCallDisconnected) {
            return const Center(
              child: Text(
                'Disconnected',
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildConnectingUI() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 20),
          Text(
            'Joining Room...',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorUI(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 60),
            const SizedBox(height: 20),
            Text(
              'Error: $message',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => context.read<VideoCallCubit>().joinRoom('testRoom1'),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectedUI(Room room) {
    return Stack(
      children: [
        // Background Grid of Participants
        Positioned.fill(
          child: ParticipantGrid(room: room),
        ),

        // Bottom Control Bar (Floating)
        Positioned(
          bottom: 40,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(
                    _isMicMuted ? Icons.mic_off : Icons.mic,
                    color: _isMicMuted ? Colors.red : Colors.white,
                  ),
                  onPressed: () {
                    setState(() => _isMicMuted = !_isMicMuted);
                    context.read<VideoCallCubit>().muteMic(_isMicMuted);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.call_end, color: Colors.red, size: 32),
                  onPressed: () {
                    context.read<VideoCallCubit>().leaveRoom();
                    Navigator.of(context).pop();
                  },
                ),
                IconButton(
                  icon: Icon(
                    _isCameraDisabled ? Icons.videocam_off : Icons.videocam,
                    color: _isCameraDisabled ? Colors.red : Colors.white,
                  ),
                  onPressed: () {
                    setState(() => _isCameraDisabled = !_isCameraDisabled);
                    context.read<VideoCallCubit>().disableCamera(_isCameraDisabled);
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A reactive grid that listens to Room events and updates the display of participants.
class ParticipantGrid extends StatefulWidget {
  final Room room;
  const ParticipantGrid({super.key, required this.room});

  @override
  State<ParticipantGrid> createState() => _ParticipantGridState();
}

class _ParticipantGridState extends State<ParticipantGrid> {
  @override
  void initState() {
    super.initState();
    // CRITICAL: Listen to room events to ensure the UI rebuilds when 
    // local/remote tracks are published or updated.
    widget.room.addListener(_onRoomUpdate);
  }

  @override
  void dispose() {
    widget.room.removeListener(_onRoomUpdate);
    super.dispose();
  }

  void _onRoomUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Participant> participants = [
      if (widget.room.localParticipant != null) widget.room.localParticipant!,
      ...widget.room.remoteParticipants.values,
    ];

    if (participants.isEmpty) {
      return const Center(
        child: Text('Connecting to media...', style: TextStyle(color: Colors.white)),
      );
    }

    final count = participants.length;
    final crossAxisCount = count <= 2 ? 1 : 2;

    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: crossAxisCount == 1 ? 0.7 : 0.8,
      ),
      itemCount: count,
      itemBuilder: (context, index) {
        return _ParticipantVideoView(
          participant: participants[index],
        );
      },
    );
  }
}

class _ParticipantVideoView extends StatelessWidget {
  final Participant participant;

  const _ParticipantVideoView({
    required this.participant,
  });

  @override
  Widget build(BuildContext context) {
    // Safely extract the first available VideoTrack from publications
    final videoTrack = participant.videoTrackPublications
        .where((pub) => pub.track is VideoTrack)
        .map((pub) => pub.track as VideoTrack)
        .firstOrNull;

    return Container(
      color: Colors.grey[900],
      child: Stack(
        children: [
          // Video Main Layer
          Positioned.fill(
            child: videoTrack != null
                ? VideoTrackRenderer(videoTrack)
                : const Center(
                    child: Icon(Icons.person, color: Colors.white24, size: 80),
                  ),
          ),
          
          // Identity Label
          Positioned(
            bottom: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${participant.identity}${participant is LocalParticipant ? ' (You)' : ''}',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
