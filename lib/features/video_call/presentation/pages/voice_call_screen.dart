import 'package:flutter/material.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';
import '../../../../core/theme/app_typography.dart';

class VoiceCallScreen extends StatelessWidget {
  final String contactName;
  final String avatarInitials;

  const VoiceCallScreen({
    Key? key,
    required this.contactName,
    required this.avatarInitials,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF555555), // Dark grey background matching the image
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 3),
            // Avatar
            CircleAvatar(
              radius: 65.resR,
              backgroundColor: const Color(0xFF8E6FB1), // Muted purple
              child: Text(
                avatarInitials,
                style: AppTypography.headline1.copyWith(
                  color: Colors.white,
                  fontSize: 50,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(height: 24.resH),
            // Name
            Text(
              contactName,
              style: AppTypography.headline3.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 24,
              ),
            ),
            SizedBox(height: 8.resH),
            // Calling Status
            Text(
              'Calling....',
              style: AppTypography.body1.copyWith(
                color: Colors.grey[400],
                fontSize: 16,
              ),
            ),
            
            const Spacer(flex: 4),
            
            // ── Bottom Controls ──────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildControlButton(Icons.videocam_off_outlined, Colors.white24, Colors.white),
                SizedBox(width: 24.resW),
                _buildControlButton(Icons.mic_none_outlined, Colors.white24, Colors.white),
                SizedBox(width: 24.resW),
                _buildControlButton(Icons.volume_up, Colors.white, Colors.green),
              ],
            ),
            SizedBox(height: 32.resH),
            
            // ── End Call Button ──────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 40.resW),
              child: SizedBox(
                width: double.infinity,
                height: 56.resH,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context), // Pops back to ChatRoomScreen
                  icon: const Icon(Icons.phone_missed, color: Colors.white),
                  label: const Text(
                    'End Call',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935), // Exact red from design
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28.resR),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ),
            SizedBox(height: 48.resH),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton(IconData icon, Color bgColor, Color iconColor) {
    return Container(
      width: 60.resW,
      height: 60.resW,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(icon, color: iconColor, size: 28.resW),
      ),
    );
  }
}
