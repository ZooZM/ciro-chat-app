import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/chat_session.dart';
import 'dart:math' as math;

class ChatInfoScreen extends StatefulWidget {
  final ChatSession chatData;

  const ChatInfoScreen({Key? key, required this.chatData}) : super(key: key);

  @override
  State<ChatInfoScreen> createState() => _ChatInfoScreenState();
}

class _ChatInfoScreenState extends State<ChatInfoScreen> {
  bool isMuted = false;
  bool isLocked = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Very light background
      appBar: AppBar(
        backgroundColor: Colors.grey[50],
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Chat information',
          style: AppTypography.subtitle1.copyWith(
            color: Colors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black, size: 24.resW),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_outlined, color: Colors.grey[700], size: 22.resW),
            onPressed: () {},
          ),
          IconButton(
            // Forward/Share icon
            icon: Transform(
              alignment: Alignment.center,
              transform: Matrix4.rotationY(math.pi),
              child: Icon(Icons.reply_outlined, color: Colors.grey[700], size: 24.resW),
            ),
            onPressed: () {},
          ),
          SizedBox(width: 8.resW),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: 40.resH),
        child: Column(
          children: [
            SizedBox(height: 16.resH),
            // ── 2. Profile Header ──────────────────────────────────────────
            _buildProfileHeader(),

            SizedBox(height: 24.resH),
            // ── 3. Quick Actions Row ───────────────────────────────────────
            _buildQuickActions(),

            SizedBox(height: 16.resH),
            // ── 4. Media Section ───────────────────────────────────────────
            _buildMediaSection(),

            SizedBox(height: 16.resH),
            // ── 5. Options Section ─────────────────────────────────────────
            _buildOptionsSection(),

            SizedBox(height: 16.resH),
            // ── 6. Shared Groups Section ───────────────────────────────────
            _buildSharedGroupsSection(),

            SizedBox(height: 16.resH),
            // ── 7. Danger Zone ─────────────────────────────────────────────
            _buildDangerZone(),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UI COMPONENTS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildProfileHeader() {
    // Generate initials for fallback
    final name = widget.chatData.name.isNotEmpty ? widget.chatData.name : 'Unknown';
    final initials = name.length >= 2 ? name.substring(0, 2).toUpperCase() : name[0].toUpperCase();

    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            CircleAvatar(
              radius: 46.resR,
              backgroundColor: const Color(0xFF8E60B8), // Muted purple from design
              backgroundImage: widget.chatData.avatarUrl.isNotEmpty
                  ? CachedNetworkImageProvider(widget.chatData.avatarUrl)
                  : null,
              child: widget.chatData.avatarUrl.isEmpty
                  ? Text(
                      initials,
                      style: AppTypography.headline1.copyWith(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  : null,
            ),
            // Online status indicator
            if (widget.chatData.isOnline)
              Container(
                width: 20.resW,
                height: 20.resW,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.grey[50]!, // matches page bg
                    width: 3.resW,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: 16.resH),
        Text(
          name,
          style: AppTypography.headline3.copyWith(
            fontWeight: FontWeight.w800,
            color: Colors.black,
            fontSize: 22,
          ),
        ),
        SizedBox(height: 4.resH),
        Text(
          widget.chatData.phoneNumber.isNotEmpty ? widget.chatData.phoneNumber : '+20111000555',
          style: AppTypography.body2.copyWith(
            color: Colors.grey[600],
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.resW),
      child: Row(
        children: [
          _buildQuickActionCard(Icons.search, 'Search'),
          SizedBox(width: 12.resW),
          _buildQuickActionCard(Icons.videocam_outlined, 'Video call'),
          SizedBox(width: 12.resW),
          _buildQuickActionCard(Icons.call_outlined, 'Voice call'),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(IconData icon, String label) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14.resH),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.resR),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 26.resW),
            SizedBox(height: 8.resH),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: Colors.grey[800],
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaSection() {
    return _buildContainerSection(
      padding: EdgeInsets.only(left: 16.resW, top: 16.resH, bottom: 16.resH), // right padding in list
      child: Column(
        children: [
          // Header
          Padding(
            padding: EdgeInsets.only(right: 16.resW, bottom: 12.resH),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Media, links and documents',
                  style: AppTypography.body2.copyWith(
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[400], size: 22.resW),
              ],
            ),
          ),
          // Horizontal Images
          SizedBox(
            height: 90.resW,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 5,
              separatorBuilder: (_, __) => SizedBox(width: 8.resW),
              itemBuilder: (context, index) {
                // Return a dummy image
                return ClipRRect(
                  borderRadius: BorderRadius.circular(10.resR),
                  child: CachedNetworkImage(
                    imageUrl: 'https://i.pravatar.cc/200?u=${index + 5}', 
                    width: 90.resW,
                    height: 90.resW,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: Colors.grey[200]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsSection() {
    return _buildContainerSection(
      padding: EdgeInsets.symmetric(vertical: 8.resH),
      child: Column(
        children: [
          _buildOptionTile('Starred Messages', Icons.star_border, AppColors.textSecondary, trailing: _arrowIcon()),
          _buildOptionTile('mute notifications', Icons.notifications_none, AppColors.textSecondary, trailing: CupertinoSwitch(
            value: isMuted,
            activeColor: AppColors.primary,
            onChanged: (v) => setState(() => isMuted = v),
          )),
          _buildOptionTile('Chat feature', Icons.palette_outlined, AppColors.textSecondary, trailing: _arrowIcon()),
          _buildOptionTile('Save in pictures', Icons.download_outlined, AppColors.textSecondary, trailing: _arrowIcon()),
          _buildOptionTile('Chat lock', Icons.lock_outline, AppColors.textSecondary, trailing: CupertinoSwitch(
             value: isLocked,
             activeColor: AppColors.primary,
             onChanged: (v) => setState(() => isLocked = v),
          )),
        ],
      ),
    );
  }

  Widget _buildSharedGroupsSection() {
    return _buildContainerSection(
      padding: EdgeInsets.symmetric(vertical: 16.resH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.resW),
            child: Text(
              '2 shared groups',
              style: AppTypography.body2.copyWith(
                color: Colors.grey[500],
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          SizedBox(height: 12.resH),
          // Group 1
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.resW, vertical: 8.resH),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF1B3A57), // Dark blue
                  radius: 20.resR,
                  child: Text('TT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.resW)),
                ),
                SizedBox(width: 16.resW),
                Text('Tech Team', style: AppTypography.subtitle2.copyWith(color: Colors.black, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          // Group 2
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.resW, vertical: 8.resH),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFC2185B), // Pinkish red
                  radius: 20.resR,
                  child: Text('PM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.resW)),
                ),
                SizedBox(width: 16.resW),
                Text('Project Managers', style: AppTypography.subtitle2.copyWith(color: Colors.black, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZone() {
    return _buildContainerSection(
      padding: EdgeInsets.symmetric(vertical: 8.resH),
      child: Column(
        children: [
          _buildOptionTile('Delete chat content', Icons.info_outline, const Color(0xFFE53935), isDanger: true),
          _buildOptionTile('Block user', Icons.person_off_outlined, const Color(0xFFE53935), isDanger: true),
          _buildOptionTile('Report', Icons.flag_outlined, const Color(0xFFE53935), isDanger: true),
          _buildOptionTile('Delete chat', Icons.delete_outline, const Color(0xFFE53935), isDanger: true),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildContainerSection({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.resW),
      padding: padding ?? EdgeInsets.all(16.resW),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.resR),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildOptionTile(String title, IconData icon, Color color, {Widget? trailing, bool isDanger = false}) {
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.resW, vertical: 12.resH),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24.resW),
            SizedBox(width: 16.resW),
            Expanded(
              child: Text(
                title,
                style: AppTypography.body1.copyWith(
                  color: isDanger ? color : Colors.grey[800],
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Widget _arrowIcon() {
    return Icon(Icons.chevron_right, color: Colors.grey[400], size: 20.resW);
  }
}
