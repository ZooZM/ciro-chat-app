import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_constants.dart';
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Chat information',
          style: AppTypography.subtitle1.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 24.resW),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_outlined, color: AppColors.textSecondary, size: 22.resW),
            onPressed: () {},
          ),
          IconButton(
            // Forward/Share icon
            icon: Transform(
              alignment: Alignment.center,
              transform: Matrix4.rotationY(math.pi),
              child: Icon(Icons.reply_outlined, color: AppColors.textSecondary, size: 24.resW),
            ),
            onPressed: () {},
          ),
          SizedBox(width: AppConstants.spacingSm.resW),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: 40.resH),
        child: Column(
          children: [
            SizedBox(height: AppConstants.spacingMd.resH),
            // ── 2. Profile Header ──────────────────────────────────────────
            _buildProfileHeader(),

            SizedBox(height: AppConstants.spacingLg.resH),
            // ── 3. Quick Actions Row ───────────────────────────────────────
            _buildQuickActions(),

            SizedBox(height: AppConstants.spacingMd.resH),
            // ── 4. Media Section ───────────────────────────────────────────
            _buildMediaSection(),

            SizedBox(height: AppConstants.spacingMd.resH),
            // ── 5. Options Section ─────────────────────────────────────────
            _buildOptionsSection(),

            SizedBox(height: AppConstants.spacingMd.resH),
            // ── 6. Shared Groups Section ───────────────────────────────────
            _buildSharedGroupsSection(),

            SizedBox(height: AppConstants.spacingMd.resH),
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
              backgroundColor: AppColors.primary,
              backgroundImage: widget.chatData.avatarUrl.isNotEmpty
                  ? CachedNetworkImageProvider(widget.chatData.avatarUrl)
                  : null,
              child: widget.chatData.avatarUrl.isEmpty
                  ? Text(
                      initials,
                      style: AppTypography.headline1.copyWith(
                        color: AppColors.surface,
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
                  color: AppColors.info,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.background,
                    width: 3.resW,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: AppConstants.spacingMd.resH),
        Text(
          name,
          style: AppTypography.headline3.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            fontSize: 22,
          ),
        ),
        SizedBox(height: AppConstants.spacingXs.resH),
        Text(
          widget.chatData.phoneNumber.isNotEmpty ? widget.chatData.phoneNumber : '',
          style: AppTypography.body2.copyWith(
            color: AppColors.textSecondary,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppConstants.spacingMd.resW),
      child: Row(
        children: [
          _buildQuickActionCard(Icons.search, 'Search'),
          SizedBox(width: AppConstants.spacingMd.resW * 0.75),
          _buildQuickActionCard(Icons.videocam_outlined, 'Video call'),
          SizedBox(width: AppConstants.spacingMd.resW * 0.75),
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
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusMd.resR),
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 26.resW),
            SizedBox(height: AppConstants.spacingSm.resH),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: AppColors.textPrimary,
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
      padding: EdgeInsets.only(left: AppConstants.spacingMd.resW, top: AppConstants.spacingMd.resH, bottom: AppConstants.spacingMd.resH),
      child: Column(
        children: [
          // Header
          Padding(
            padding: EdgeInsets.only(right: AppConstants.spacingMd.resW, bottom: AppConstants.spacingMd.resH * 0.75),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Media, links and documents',
                  style: AppTypography.body2.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Icon(Icons.chevron_right, color: AppColors.textHint, size: 22.resW),
              ],
            ),
          ),
          // Horizontal Images
          SizedBox(
            height: 90.resW,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 5,
              separatorBuilder: (_, __) => SizedBox(width: AppConstants.spacingSm.resW),
              itemBuilder: (context, index) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm.resR + 2),
                  child: CachedNetworkImage(
                    imageUrl: 'https://i.pravatar.cc/200?u=${index + 5}', 
                    width: 90.resW,
                    height: 90.resW,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: AppColors.surfaceVariant),
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
      padding: EdgeInsets.symmetric(vertical: AppConstants.spacingSm.resH),
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
      padding: EdgeInsets.symmetric(vertical: AppConstants.spacingMd.resH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppConstants.spacingMd.resW),
            child: Text(
              '2 shared groups',
              style: AppTypography.body2.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          SizedBox(height: AppConstants.spacingMd.resH * 0.75),
          // Group 1
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppConstants.spacingMd.resW, vertical: AppConstants.spacingSm.resH),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.secondaryDark,
                  radius: 20.resR,
                  child: Text('TT', style: TextStyle(color: AppColors.surface, fontWeight: FontWeight.w600, fontSize: 13.resW)),
                ),
                SizedBox(width: AppConstants.spacingMd.resW),
                Text('Tech Team', style: AppTypography.subtitle2.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          // Group 2
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppConstants.spacingMd.resW, vertical: AppConstants.spacingSm.resH),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.error,
                  radius: 20.resR,
                  child: Text('PM', style: TextStyle(color: AppColors.surface, fontWeight: FontWeight.w600, fontSize: 13.resW)),
                ),
                SizedBox(width: AppConstants.spacingMd.resW),
                Text('Project Managers', style: AppTypography.subtitle2.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZone() {
    return _buildContainerSection(
      padding: EdgeInsets.symmetric(vertical: AppConstants.spacingSm.resH),
      child: Column(
        children: [
          _buildOptionTile('Delete chat content', Icons.info_outline, AppColors.error, isDanger: true),
          _buildOptionTile('Block user', Icons.person_off_outlined, AppColors.error, isDanger: true),
          _buildOptionTile('Report', Icons.flag_outlined, AppColors.error, isDanger: true),
          _buildOptionTile('Delete chat', Icons.delete_outline, AppColors.error, isDanger: true),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildContainerSection({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: AppConstants.spacingMd.resW),
      padding: padding ?? EdgeInsets.all(AppConstants.spacingMd.resW),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppConstants.spacingMd.resR),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withOpacity(0.015),
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
        padding: EdgeInsets.symmetric(horizontal: AppConstants.spacingMd.resW, vertical: AppConstants.spacingMd.resH * 0.75),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24.resW),
            SizedBox(width: AppConstants.spacingMd.resW),
            Expanded(
              child: Text(
                title,
                style: AppTypography.body1.copyWith(
                  color: isDanger ? color : AppColors.textPrimary,
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
    return Icon(Icons.chevron_right, color: AppColors.textHint, size: 20.resW);
  }
}
