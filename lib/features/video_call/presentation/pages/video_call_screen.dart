import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

class VideoCallScreen extends StatefulWidget {
  final String contactName;
  final String livekitUrl;
  final String livekitToken;

  const VideoCallScreen({
    super.key,
    required this.contactName,
    required this.livekitUrl,
    required this.livekitToken,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  Room? _room;
  bool _isConnecting = true;
  bool _isMicMuted = false;
  bool _isCameraDisabled = false;

  @override
  void initState() {
    super.initState();
    _connectToRoom();
  }

  Future<void> _connectToRoom() async {
    try {
      _room = Room();
      
      // Listen to peer connection events native to the LiveKit Room!
      _room!.addListener(_onRoomUpdate);

      await _room!.connect(widget.livekitUrl, widget.livekitToken);

      // Publish local media tracks immediately upon connecting
      await _room!.localParticipant?.setCameraEnabled(true);
      await _room!.localParticipant?.setMicrophoneEnabled(true);

      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isConnecting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _onRoomUpdate() {
    if (mounted) {
      setState(() {});
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
    if (_isConnecting || _room == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 20),
              Text('Connecting to ${widget.contactName}...', style: const TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
        ),
      );
    }

    final localParticipant = _room!.localParticipant;
    final remoteParticipant = _room!.remoteParticipants.values.firstOrNull;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background - Remote VideoTrack
          Positioned.fill(
            child: _ParticipantVideoView(participant: remoteParticipant),
          ),

          // PiP - Local VideoTrack
          Positioned(
            top: 60,
            right: 20,
            width: 120,
            height: 180,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              clipBehavior: Clip.antiAlias,
              child: _ParticipantVideoView(participant: localParticipant, isLocal: true),
            ),
          ),

          // Control Bar
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: Icon(
                      _isMicMuted ? Icons.mic_off : Icons.mic,
                      color: _isMicMuted ? Colors.red : Colors.white,
                    ),
                    onPressed: () async {
                      final targetState = !_isMicMuted;
                      await _room!.localParticipant?.setMicrophoneEnabled(!targetState);
                      setState(() => _isMicMuted = targetState);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.call_end, color: Colors.white, size: 32),
                    style: IconButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () async {
                      await _room?.disconnect();
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      _isCameraDisabled ? Icons.videocam_off : Icons.videocam,
                      color: _isCameraDisabled ? Colors.red : Colors.white,
                    ),
                    onPressed: () async {
                      final targetState = !_isCameraDisabled;
                      await _room!.localParticipant?.setCameraEnabled(!targetState);
                      setState(() => _isCameraDisabled = targetState);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParticipantVideoView extends StatelessWidget {
  final Participant? participant;
  final bool isLocal;

  const _ParticipantVideoView({this.participant, this.isLocal = false});

  @override
  Widget build(BuildContext context) {
    if (participant == null) {
      return Container(
        color: Colors.grey[900],
        child: Center(
          child: Text(
            isLocal ? 'Starting camera...' : 'Waiting for remote...',
            style: const TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    final videoTrack = participant!.videoTrackPublications
        .where((pub) => pub.track is VideoTrack)
        .map((pub) => pub.track as VideoTrack)
        .firstOrNull;

    if (videoTrack != null) {
      return VideoTrackRenderer(videoTrack);
    }

    return Container(
      color: Colors.grey[900],
      child: const Center(child: Icon(Icons.person, color: Colors.white24, size: 80)),
    );
  }
}
