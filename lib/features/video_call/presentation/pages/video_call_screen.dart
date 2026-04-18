import 'package:flutter/material.dart';
import 'dart:ui';

class VideoCallScreen extends StatefulWidget {
  final String contactName;

  const VideoCallScreen({
    super.key,
    this.contactName = 'Ahmed Khaled',
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen>
    with SingleTickerProviderStateMixin {
  bool _isMicMuted = false;
  bool _isCameraOff = false;
  bool _isCaptionsOn = false;

  // Simulated call duration timer
  int _seconds = 4;
  late final AnimationController _timerController;

  @override
  void initState() {
    super.initState();
    // Tick the call timer every second
    _timerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          if (mounted) {
            setState(() => _seconds++);
            _timerController.forward(from: 0);
          }
        }
      });
    _timerController.forward();
  }

  @override
  void dispose() {
    _timerController.dispose();
    super.dispose();
  }

  String get _formattedTime {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Remote Video Feed (Full-Screen Placeholder) ──────────────────
          _buildRemoteVideo(),

          // ── Dark gradient overlay – bottom half only ─────────────────────
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.35),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withOpacity(0.70),
                  ],
                  stops: const [0.0, 0.25, 0.55, 1.0],
                ),
              ),
            ),
          ),

          // ── Top Overlay: Name + Timer + PiP ─────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name & Timer
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.contactName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formattedTime,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // ── Local Camera PiP ────────────────────────────────────
                  Container(
                    width: 110,
                    height: 150,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A5568),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.6), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: _isCameraOff
                        ? const Center(
                            child: Icon(Icons.videocam_off, color: Colors.white54, size: 36),
                          )
                        : Stack(
                            fit: StackFit.expand,
                            children: [
                              // Local camera placeholder
                              Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [Color(0xFF4A5568), Color(0xFF2D3748)],
                                  ),
                                ),
                              ),
                              const Center(
                                child: Icon(Icons.person, color: Colors.white30, size: 56),
                              ),
                              Align(
                                alignment: Alignment.bottomLeft,
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text(
                                    'You',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.85),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),

          // ── Live Caption Subtitle ────────────────────────────────────────
          if (_isCaptionsOn)
            Positioned(
              left: 16,
              right: 16,
              bottom: 150,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Doing great! Are you free for the meeting\ntomorrow?',
                  style: TextStyle(color: Colors.white, fontSize: 16, height: 1.4),
                ),
              ),
            ),

          // ── Bottom Control Row ───────────────────────────────────────────
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // Calling status text
                Text(
                  'جاري الاتصال...',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 20),

                // Control buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // CC / Captions
                    _buildControlButton(
                      icon: Icons.closed_caption_outlined,
                      isActive: _isCaptionsOn,
                      onTap: () => setState(() => _isCaptionsOn = !_isCaptionsOn),
                    ),

                    // Microphone toggle
                    _buildControlButton(
                      icon: _isMicMuted ? Icons.mic_off : Icons.mic,
                      isActive: _isMicMuted,
                      onTap: () => setState(() => _isMicMuted = !_isMicMuted),
                    ),

                    // Camera toggle
                    _buildControlButton(
                      icon: _isCameraOff ? Icons.videocam_off : Icons.videocam,
                      isActive: _isCameraOff,
                      onTap: () => setState(() => _isCameraOff = !_isCameraOff),
                    ),

                    // End Call — Red, prominent
                    _buildControlButton(
                      icon: Icons.call_end,
                      backgroundColor: Colors.red,
                      iconColor: Colors.white,
                      size: 60,
                      onTap: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemoteVideo() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3D5A6B), Color(0xFF1A2830)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.person, color: Colors.white10, size: 200),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isActive = false,
    Color? backgroundColor,
    Color iconColor = Colors.white,
    double size = 56,
  }) {
    final bgColor = backgroundColor ??
        (isActive
            ? Colors.white
            : Colors.white.withOpacity(0.20));
    final fgColor = isActive && backgroundColor == null ? Colors.black : iconColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withOpacity(0.15),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, color: fgColor, size: size * 0.44),
      ),
    );
  }
}
