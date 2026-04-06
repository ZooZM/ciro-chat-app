import 'package:flutter/material.dart';
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: BlocBuilder<VideoCallCubit, VideoCallState>(
        builder: (context, state) {
          if (state is VideoCallInitial || state is VideoCallConnecting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          } else if (state is VideoCallError) {
            return _buildErrorState(context, state.message);
          } else if (state is VideoCallConnected) {
            return _buildConnectedState(context, state.room);
          } else if (state is VideoCallDisconnected) {
            return const Center(
              child: Text(
                'Call Ended',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Error: $message',
            style: const TextStyle(color: Colors.red, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedState(BuildContext context, Room room) {
    final remoteParticipant = room.remoteParticipants.values.firstOrNull;
    final localParticipant = room.localParticipant;

    return Stack(
      children: [
        // Background: Remote Video
        Positioned.fill(
          child: _renderParticipant(remoteParticipant),
        ),

        // PIP: Local Video
        Positioned(
          top: 60,
          right: 20,
          width: 120,
          height: 160,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            clipBehavior: Clip.antiAlias,
            child: _renderParticipant(localParticipant),
          ),
        ),

        // Bottom Controls
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FloatingActionButton(
                heroTag: 'mic_btn',
                backgroundColor: _isMicMuted ? Colors.red : Colors.grey[800],
                onPressed: () {
                  setState(() => _isMicMuted = !_isMicMuted);
                  context.read<VideoCallCubit>().muteMic(_isMicMuted);
                },
                child: Icon(
                  _isMicMuted ? Icons.mic_off : Icons.mic,
                  color: Colors.white,
                ),
              ),
              FloatingActionButton(
                heroTag: 'end_btn',
                backgroundColor: Colors.red,
                onPressed: () {
                  context.read<VideoCallCubit>().leaveRoom();
                  Navigator.of(context).pop();
                },
                child: const Icon(Icons.call_end, color: Colors.white),
              ),
              FloatingActionButton(
                heroTag: 'cam_btn',
                backgroundColor: _isCameraDisabled ? Colors.red : Colors.grey[800],
                onPressed: () {
                  setState(() => _isCameraDisabled = !_isCameraDisabled);
                  context.read<VideoCallCubit>().disableCamera(_isCameraDisabled);
                },
                child: Icon(
                  _isCameraDisabled ? Icons.videocam_off : Icons.videocam,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _renderParticipant(Participant? participant) {
    if (participant == null) {
      return const Center(
        child: Text(
          'Waiting...',
          style: TextStyle(color: Colors.white54, fontSize: 16),
        ),
      );
    }

    VideoTrack? videoTrack;
    for (final publication in participant.videoTrackPublications) {
      if (publication.track != null) {
        videoTrack = publication.track as VideoTrack?;
        // Break on the first available video track
        break;
      }
    }

    if (videoTrack != null) {
      return VideoTrackRenderer(videoTrack);
    }

    return const Center(
      child: Icon(Icons.person, color: Colors.white54, size: 64),
    );
  }
}
