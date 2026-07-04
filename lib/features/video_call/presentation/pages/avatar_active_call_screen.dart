import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/helpers/responsive.dart';

class AvatarActiveCallScreen extends StatelessWidget {
  final String remoteName;
  final String remoteAvatarUrl;
  final String localAvatarUrl;
  final String localName;
  final bool isMuted;
  final bool isCameraOff;
  final String callDuration;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleCamera;
  final VoidCallback onEndCall;
  final VoidCallback? onMinimize;

  const AvatarActiveCallScreen({
    Key? key,
    required this.remoteName,
    this.remoteAvatarUrl = '',
    this.localAvatarUrl = '',
    this.localName = 'You',
    this.isMuted = false,
    this.isCameraOff = false,
    this.callDuration = '00:00',
    required this.onToggleMute,
    required this.onToggleCamera,
    required this.onEndCall,
    this.onMinimize,
  }) : super(key: key);

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEA4071), // Adjusted dark pink background
      body: SafeArea(
        child: Stack(
          children: [
            // Top Bar
            Positioned(
              top: 16.resH,
              left: 16.resW,
              right: 16.resW,
              child: Container(
                height: 72.resH,
                padding: EdgeInsets.symmetric(horizontal: 12.resW),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(40.resR),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Left: Checkmark
                    Positioned(
                      left: 0,
                      child: GestureDetector(
                        onTap: onMinimize,
                        child: Container(
                          width: 44.resR,
                          height: 44.resR,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE5395A), // Solid dark red
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 26.resR,
                          ),
                        ),
                      ),
                    ),
                    
                    // Center: Info and Avatar
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.chevron_left,
                                  color: Colors.white,
                                  size: 20.resR,
                                ),
                                SizedBox(width: 4.resW),
                                Text(
                                  remoteName,
                                  style: AppTypography.subtitle1.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 18.resSp,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              callDuration,
                              style: AppTypography.subtitle2.copyWith(
                                color: Colors.white70,
                                fontSize: 13.resSp,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(width: 12.resW),
                        CircleAvatar(
                          radius: 20.resR,
                          backgroundColor: Colors.transparent,
                          backgroundImage: remoteAvatarUrl.isNotEmpty
                              ? CachedNetworkImageProvider(remoteAvatarUrl)
                              : null,
                          child: remoteAvatarUrl.isEmpty
                              ? Text(
                                  _getInitials(remoteName),
                                  style: AppTypography.subtitle2.copyWith(
                                    color: Colors.white,
                                    fontSize: 14.resSp,
                                  ),
                                )
                              : null,
                        ),
                      ],
                    ),

                    // Right: Down arrow
                    Positioned(
                      right: 4.resW,
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.white,
                        size: 24.resR,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // PIP Avatar (Left)
            Positioned(
              left: 16.resW,
              top: 110.resH,
              child: Container(
                width: 100.resR,
                height: 170.resR,
                decoration: BoxDecoration(
                  color: const Color(0xFFF35C8D), // Matches the image PIP background
                  borderRadius: BorderRadius.circular(24.resR),
                ),
                alignment: Alignment.center,
                child: CircleAvatar(
                  radius: 35.resR,
                  backgroundColor: Colors.black12,
                  backgroundImage: localAvatarUrl.isNotEmpty
                      ? CachedNetworkImageProvider(localAvatarUrl)
                      : null,
                  child: localAvatarUrl.isEmpty
                      ? Text(
                          _getInitials(localName),
                          style: AppTypography.headline2.copyWith(
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
              ),
            ),

            // Large Center Avatar
            Center(
              child: Container(
                width: 280.resR,
                height: 280.resR,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.12), // More visible darker circle
                ),
                alignment: Alignment.center,
                child: CircleAvatar(
                  radius: 110.resR,
                  backgroundColor: Colors.transparent,
                  backgroundImage: remoteAvatarUrl.isNotEmpty
                      ? CachedNetworkImageProvider(remoteAvatarUrl)
                      : null,
                  child: remoteAvatarUrl.isEmpty
                      ? Text(
                          _getInitials(remoteName),
                          style: AppTypography.headline1.copyWith(
                            color: Colors.white,
                            fontSize: 64.resSp,
                          ),
                        )
                      : null,
                ),
              ),
            ),

            // Bottom White Circle
            Positioned(
              bottom: 150.resH,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 80.resR,
                  height: 80.resR,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4.5.resR),
                  ),
                ),
              ),
            ),

            // Bottom Control Bar
            Positioned(
              bottom: 24.resH,
              left: 16.resW,
              right: 16.resW,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40.resR),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      vertical: 12.resH,
                      horizontal: 16.resW,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildIconBtn(
                          Icons.arrow_upward_rounded,
                          onTap: () {},
                        ), // Upload arrow
                        _buildIconBtn(
                          Icons.sentiment_satisfied_alt,
                          onTap: () {},
                        ), // Smiley face
                        _buildIconBtn(
                          isMuted ? Icons.mic_off : Icons.mic,
                          onTap: onToggleMute,
                          isActive: isMuted,
                        ), // Microphone
                        _buildIconBtn(
                          Icons.sync,
                          onTap: onToggleCamera,
                        ), // Reverse camera
                        // White round button with red camera icon
                        GestureDetector(
                          onTap: onEndCall,
                          child: Container(
                            width: 52.resR,
                            height: 52.resR,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.videocam_off,
                              color: const Color(0xFFE33451),
                              size: 26.resR,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconBtn(
    IconData icon, {
    VoidCallback? onTap,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52.resR,
        height: 52.resR,
        decoration: BoxDecoration(
          color: isActive
              ? Colors.white.withOpacity(0.4)
              : Colors.white.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 24.resR),
      ),
    );
  }
}
