import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ciro_chat_app/core/routing/app_router.dart';
import 'package:ciro_chat_app/core/utils/url_utils.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';
import 'package:ciro_chat_app/core/theme/app_colors.dart';
import 'package:ciro_chat_app/core/theme/app_typography.dart';
import 'package:ciro_chat_app/features/chat/domain/entities/chat_session.dart';
import 'package:ciro_chat_app/features/chat/presentation/bloc/chat_cubit.dart';
import '../widgets/group_participant_tile.dart';

class GroupInfoPage extends StatefulWidget {
  final ChatSession chatData;

  const GroupInfoPage({Key? key, required this.chatData}) : super(key: key);

  @override
  State<GroupInfoPage> createState() => _GroupInfoPageState();
}

class _GroupInfoPageState extends State<GroupInfoPage> {
  late String _currentUserPhone;
  bool _isUploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _currentUserPhone = context.read<ChatCubit>().currentUserPhone;
  }

  Future<void> _pickAvatar(ChatSession chat) async {
    final cubit = context.read<ChatCubit>();
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    if (!mounted) return;
    setState(() => _isUploadingAvatar = true);
    try {
      final url = await cubit.uploadGroupAvatar(File(picked.path));
      if (!mounted) return;
      if (url != null && url.isNotEmpty) {
        await cubit.updateGroupAvatar(chat.id, url);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Avatar upload failed. Group photo not changed.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  void _showAddParticipants(ChatSession currentChatData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return _AddParticipantsSheet(
          roomId: currentChatData.id,
          existingParticipants: currentChatData.participants,
        );
      },
    );
  }

  void _removeParticipant(ChatSession currentChatData, String phoneNumber) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Remove Participant'),
        content: Text('Are you sure you want to remove $phoneNumber from the group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppColors.textPrimary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<ChatCubit>().removeParticipant(
                currentChatData.id,
                phoneNumber,
              );
            },
            child: Text('Remove', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _leaveGroup(ChatSession currentChatData) {
    final isLastAdmin = currentChatData.admins.length == 1 &&
        currentChatData.admins.contains(_currentUserPhone);
    final hasOtherMembers = currentChatData.participants.length > 1;
    final body = isLastAdmin && hasOtherMembers
        ? 'You will leave this group. The earliest-joining member will be promoted to admin.'
        : 'Are you sure you want to leave this group?';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Leave Group'),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppColors.textPrimary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<ChatCubit>().leaveGroup(currentChatData.id);
              context.go(AppRouterName.home);
            },
            child: Text('Leave', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, ChatSession chat) {
    final cubit = context.read<ChatCubit>();
    final controller = TextEditingController(text: chat.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Edit Group Name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Group Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != chat.name) {
                cubit.updateGroupName(chat.id, newName);
              }
              Navigator.pop(ctx);
            },
            child: Text('Save', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ChatSession>>(
      stream: context.read<ChatCubit>().recentChatsStream,
      builder: (context, snapshot) {
        final currentChatData = snapshot.data?.firstWhere(
              (r) => r.id == widget.chatData.id,
              orElse: () => widget.chatData,
            ) ??
            widget.chatData;

        final bool isAdmin = currentChatData.admins.contains(_currentUserPhone);

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            elevation: 0,
            centerTitle: true,
            title: const Text(
              'Group information',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
              onPressed: () => context.pop(),
            ),
            actions: [
              if (isAdmin)
                IconButton(
                  icon: Icon(Icons.edit, color: AppColors.textPrimary),
                  onPressed: () => _showEditDialog(context, currentChatData),
                ),
            ],
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.resW, vertical: 8.resH),
              child: Column(
                children: [
                  _buildHeader(currentChatData),
                  SizedBox(height: 24.resH),
                  _buildActionButtons(),
                  SizedBox(height: 16.resH),
                  _buildDescriptionTile(currentChatData),
                  SizedBox(height: 16.resH),
                  _buildMediaSection(),
                  SizedBox(height: 16.resH),
                  _buildSettingsSection(),
                  SizedBox(height: 16.resH),
                  _buildMembersSection(currentChatData, isAdmin),
                  SizedBox(height: 16.resH),
                  _buildDangerZone(currentChatData),
                  SizedBox(height: 40.resH),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(ChatSession chat) {
    final isAdmin = chat.admins.contains(_currentUserPhone);
    final initials = chat.name.isNotEmpty
        ? (chat.name.length >= 2
            ? chat.name.substring(0, 2).toUpperCase()
            : chat.name[0].toUpperCase())
        : 'G';

    final avatar = CircleAvatar(
      radius: 45.resR,
      backgroundColor: AppColors.primary,
      backgroundImage: chat.avatarUrl.isNotEmpty
          ? CachedNetworkImageProvider(UrlUtils.resolveMediaUrl(chat.avatarUrl))
          : null,
      child: _isUploadingAvatar
          ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
          : chat.avatarUrl.isEmpty
              ? Text(
                  initials,
                  style: TextStyle(
                    color: AppColors.surface,
                    fontSize: 32.resH,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
    );

    return Column(
      children: [
        isAdmin
            ? GestureDetector(
                onTap: () => _pickAvatar(chat),
                child: Stack(
                  children: [
                    avatar,
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: CircleAvatar(
                        radius: 13.resR,
                        backgroundColor: AppColors.primary,
                        child: Icon(Icons.camera_alt, color: Colors.white, size: 14.resR),
                      ),
                    ),
                  ],
                ),
              )
            : avatar,
        SizedBox(height: 12.resH),
        Text(
          chat.name.isEmpty ? 'Unknown Group' : chat.name,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22.resH,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4.resH),
        Text(
          '${chat.participants.length} members',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 14.resH,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildActionButton(Icons.search, 'Search'),
        _buildActionButton(Icons.person_add_alt, 'Add'),
        _buildActionButton(Icons.videocam, 'Video call'),
        _buildActionButton(Icons.call, 'Voice call'),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label) {
    return Expanded(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 4.resW),
        padding: EdgeInsets.symmetric(vertical: 12.resH),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.resR),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.primary, size: 28.resR),
            SizedBox(height: 8.resH),
            Text(
              label,
              style: TextStyle(fontSize: 12.resH, color: AppColors.textPrimary),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionTile(ChatSession chat) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.resW),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12.resR),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            chat.description.isEmpty ? 'Add group description' : chat.description,
            style: TextStyle(
              color: chat.description.isEmpty ? AppColors.primary : AppColors.textPrimary,
              fontSize: 14.resH,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.resW),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12.resR),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Media, links and documents',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14.resH),
              ),
              Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
          SizedBox(height: 16.resH),
          Text(
            'No media found',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14.resH),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12.resR),
      ),
      child: Column(
        children: [
          _buildSettingsTile(
            Icons.star_border,
            'Starred Messages',
            trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ),
          _buildSettingsTile(
            Icons.notifications_none,
            'mute notifications',
            trailing: CupertinoSwitch(
              value: false,
              onChanged: (v) {},
              activeColor: AppColors.primary,
            ),
          ),
          _buildSettingsTile(
            Icons.palette_outlined,
            'Chat feature',
            trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ),
          _buildSettingsTile(
            Icons.download_outlined,
            'Save in pictures',
            trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ),
          _buildSettingsTile(
            Icons.lock_outline,
            'Chat lock',
            trailing: CupertinoSwitch(
              value: false,
              onChanged: (v) {},
              activeColor: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, {required Widget trailing}) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(title, style: TextStyle(color: AppColors.textPrimary)),
      trailing: trailing,
      dense: true,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildMembersSection(ChatSession chat, bool isAdmin) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12.resR),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16.resW),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${chat.participants.length} member${chat.participants.length > 1 ? 's' : ''}',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14.resH),
                ),
                Icon(Icons.search, color: AppColors.textSecondary),
              ],
            ),
          ),
          if (isAdmin) ...[
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.transparent,
                child: Icon(Icons.add_circle_outline, color: AppColors.textSecondary, size: 28),
              ),
              title: Text('Add member', style: TextStyle(color: AppColors.textPrimary)),
              dense: true,
              onTap: () => _showAddParticipants(chat),
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.transparent,
                child: Icon(Icons.qr_code_2, color: AppColors.textSecondary, size: 28),
              ),
              title: Text('Invite via link or QR code', style: TextStyle(color: AppColors.textPrimary)),
              dense: true,
            ),
          ],
          ...chat.participants.map((phone) {
            return GroupParticipantTile(
              phoneNumber: phone,
              isAdmin: chat.admins.contains(phone),
              isMe: phone == _currentUserPhone,
              showRemoveAction: isAdmin,
              onRemove: () => _removeParticipant(chat, phone),
            );
          }).toList(),
          SizedBox(height: 8.resH),
        ],
      ),
    );
  }

  Widget _buildDangerZone(ChatSession chat) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.resR),
      ),
      child: Column(
        children: [
          _buildDangerTile(Icons.info_outline, 'Delete chat content'),
          _buildDangerTile(Icons.person_off_outlined, 'Block user'),
          _buildDangerTile(Icons.flag_outlined, 'Report'),
          ListTile(
            leading: Icon(Icons.delete_outline, color: AppColors.error),
            title: Text('Leave group', style: TextStyle(color: AppColors.error)),
            dense: true,
            visualDensity: VisualDensity.compact,
            onTap: () => _leaveGroup(chat),
          ),
        ],
      ),
    );
  }

  Widget _buildDangerTile(IconData icon, String title) {
    return ListTile(
      leading: Icon(icon, color: AppColors.error),
      title: Text(title, style: TextStyle(color: AppColors.error)),
      dense: true,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _AddParticipantsSheet extends StatefulWidget {
  final String roomId;
  final List<String> existingParticipants;

  const _AddParticipantsSheet({
    required this.roomId,
    required this.existingParticipants,
  });

  @override
  State<_AddParticipantsSheet> createState() => _AddParticipantsSheetState();
}

class _AddParticipantsSheetState extends State<_AddParticipantsSheet> {
  final Set<String> _selectedPhones = {};
  bool _isSubmitting = false;

  void _toggleSelection(String phone) {
    setState(() {
      if (_selectedPhones.contains(phone)) {
        _selectedPhones.remove(phone);
      } else {
        _selectedPhones.add(phone);
      }
    });
  }

  void _submit() async {
    if (_selectedPhones.isEmpty) return;
    setState(() => _isSubmitting = true);
    await context.read<ChatCubit>().addParticipants(
      widget.roomId,
      _selectedPhones.toList(),
    );
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16.resW),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Add Participants', style: AppTypography.headline3),
                if (_isSubmitting)
                  const CircularProgressIndicator()
                else
                  TextButton(
                    onPressed: _selectedPhones.isEmpty ? null : _submit,
                    child: const Text('Add'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<ChatSession>>(
              stream: context.read<ChatCubit>().watchLocalContacts,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final contacts = snapshot.data!
                    .where(
                      (c) => !widget.existingParticipants.contains(c.phoneNumber),
                    )
                    .toList();

                if (contacts.isEmpty) {
                  return const Center(child: Text('No new contacts to add'));
                }

                return ListView.builder(
                  itemCount: contacts.length,
                  itemBuilder: (context, index) {
                    final contact = contacts[index];
                    final isSelected = _selectedPhones.contains(contact.phoneNumber);
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        child: Text(
                          contact.name.isNotEmpty ? contact.name[0] : '?',
                          style: const TextStyle(color: AppColors.primary),
                        ),
                      ),
                      title: Text(contact.name),
                      subtitle: Text(contact.phoneNumber),
                      trailing: Checkbox(
                        value: isSelected,
                        onChanged: (_) => _toggleSelection(contact.phoneNumber),
                      ),
                      onTap: () => _toggleSelection(contact.phoneNumber),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

