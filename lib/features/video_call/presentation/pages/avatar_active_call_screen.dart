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
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE57373), // Coral/Red top
              Color(0xFFD32F2F), // Darker red bottom
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Main content
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Top Bar
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.resW, vertical: 16.resH),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 28.resR),
                          onPressed: onMinimize,
                        ),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 14.resR,
                                backgroundColor: Colors.white24,
                                backgroundImage: remoteAvatarUrl.isNotEmpty
                                    ? CachedNetworkImageProvider(remoteAvatarUrl)
                                    : null,
                                child: remoteAvatarUrl.isEmpty
                                    ? Text(
                                        _getInitials(remoteName),
                                        style: AppTypography.subtitle2.copyWith(color: Colors.white, fontSize: 10.resSp),
                                      )
                                    : null,
                              ),
                              SizedBox(width: 8.resW),
                              Flexible(
                                child: Text(
                                  remoteName,
                                  style: AppTypography.subtitle1.copyWith(color: Colors.white),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(width: 8.resW),
                              Text(
                                callDuration,
                                style: AppTypography.subtitle2.copyWith(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.volume_up, color: Colors.white, size: 24.resR),
                        SizedBox(width: 12.resW),
                        GestureDetector(
                          onTap: onEndCall,
                          child: Container(
                            padding: EdgeInsets.all(8.resR),
                            decoration: const BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.call_end, color: Colors.white, size: 20.resR),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // Large Avatar
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.1),
                    ),
                    padding: EdgeInsets.all(24.resR),
                    child: CircleAvatar(
                      radius: 100.resR,
                      backgroundColor: AppColors.primary,
                      backgroundImage: remoteAvatarUrl.isNotEmpty
                          ? CachedNetworkImageProvider(remoteAvatarUrl)
                          : null,
                      child: remoteAvatarUrl.isEmpty
                          ? Text(
                              _getInitials(remoteName),
                              style: AppTypography.headline1.copyWith(color: Colors.white, fontSize: 64.resSp),
                            )
                          : null,
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // Camera Shutter Placeholder
                  Container(
                    width: 64.resR,
                    height: 64.resR,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4.resR),
                    ),
                  ),
                  
                  SizedBox(height: 100.resH), // Space for bottom controls
                ],
              ),
              
              // PIP Avatar (Bottom-left)
              Positioned(
                left: 24.resW,
                bottom: 120.resH,
                child: Container(
                  width: 80.resR,
                  height: 120.resR,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(12.resR),
                    border: Border.all(color: Colors.white, width: 2.resR),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _getInitials(localName),
                    style: AppTypography.subtitle1.copyWith(color: AppColors.primary),
                  ),
                ),
              ),
              
              // Bottom Control Bar
              Align(
                alignment: Alignment.bottomCenter,
                child: ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 24.resH, horizontal: 16.resW),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildControlButton(
                            icon: isCameraOff ? Icons.videocam_off : Icons.videocam,
                            label: 'call_btn_camera'.tr(),
                            isActive: isCameraOff,
                            onTap: onToggleCamera,
                          ),
                          _buildControlButton(
                            icon: Icons.flip_camera_ios,
                            label: 'Flip', // No specific requirement to translate this
                            isActive: false,
                            onTap: () {},
                          ),
                          _buildControlButton(
                            icon: isMuted ? Icons.mic_off : Icons.mic,
                            label: 'call_btn_mute'.tr(),
                            isActive: isMuted,
                            onTap: onToggleMute,
                          ),
                          _buildControlButton(
                            icon: Icons.emoji_emotions_outlined,
                            label: 'Emoji',
                            isActive: false,
                            onTap: () {},
                          ),
                          _buildControlButton(
                            icon: Icons.screen_share_outlined,
                            label: 'Share',
                            isActive: false,
                            onTap: () {},
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
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(12.resR),
            decoration: BoxDecoration(
              color: isActive ? AppColors.error : Colors.white24,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24.resR),
          ),
          SizedBox(height: 8.resH),
          Text(
            label,
            style: AppTypography.caption.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}
