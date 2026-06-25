import 'dart:io';

import 'package:ciro_chat_app/core/di/injection.dart';
import 'package:ciro_chat_app/core/routing/app_router.dart';
import 'package:ciro_chat_app/features/map/presentation/bloc/map_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';
import 'package:ciro_chat_app/core/utils/url_utils.dart';
import 'package:ciro_chat_app/core/theme/app_colors.dart';
import 'package:ciro_chat_app/core/theme/app_typography.dart';
import 'package:ciro_chat_app/features/chat/domain/entities/chat_session.dart';
import 'package:ciro_chat_app/features/chat/presentation/bloc/chat_cubit.dart';

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final TextEditingController _nameController = TextEditingController();
  final Set<String> _selectedContactIds = {};
  final ImagePicker _picker = ImagePicker();

  bool _isCreating = false;
  bool _isUploadingAvatar = false;
  File? _avatarFile;
  String? _avatarUrl;

  void _toggleSelection(String contactId) {
    setState(() {
      if (_selectedContactIds.contains(contactId)) {
        _selectedContactIds.remove(contactId);
      } else {
        _selectedContactIds.add(contactId);
      }
    });
  }

  Future<void> _pickAvatar() async {
    final cubit = context.read<ChatCubit>();
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() {
        _avatarFile = File(picked.path);
        _isUploadingAvatar = true;
      });

      final url = await cubit.uploadGroupAvatar(_avatarFile!);

      if (!mounted) return;
      if (url == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Avatar upload failed — group will be created without a photo',
            ),
          ),
        );
      }
      setState(() {
        _avatarUrl = url;
        _isUploadingAvatar = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to pick avatar')));
    }
  }

  Future<void> _createGroup() async {
    final groupName = _nameController.text.trim();
    if (groupName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group name')),
      );
      return;
    }
    if (_selectedContactIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one contact')),
      );
      return;
    }

    setState(() => _isCreating = true);
    await context.read<ChatCubit>().createGroup(
      groupName,
      _selectedContactIds.toList(),
      avatarUrl: _avatarUrl,
    );

    if (mounted) {
      setState(() => _isCreating = false);
      final state = context.read<ChatCubit>().state;
      if (state is ChatError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.message),
            backgroundColor: AppColors.error,
          ),
        );
      } else {
        // A new GROUP-type chat room also feeds the Map's group filter
        // (FR-017/023) — refresh it regardless of where this page was
        // opened from, so a group created from Chats shows up there too.
        getIt<MapCubit>().loadGroups();
        context.go(AppRouterName.home);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Widget _buildAvatarPicker() {
    return GestureDetector(
      onTap: _isUploadingAvatar ? null : _pickAvatar,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            backgroundImage: _avatarFile != null
                ? FileImage(_avatarFile!)
                : null,
            child: _avatarFile == null
                ? Icon(Icons.group, size: 36, color: AppColors.primary)
                : null,
          ),
          if (_isUploadingAvatar)
            const Positioned.fill(
              child: CircleAvatar(
                backgroundColor: Colors.black38,
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          if (!_isUploadingAvatar)
            CircleAvatar(
              radius: 13,
              backgroundColor: AppColors.primary,
              child: const Icon(
                Icons.camera_alt,
                size: 14,
                color: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'New Group',
          style: AppTypography.headline2.copyWith(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black, size: 24.resW),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_isCreating)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _createGroup,
              child: Text(
                'Create',
                style: AppTypography.subtitle1.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              vertical: 16.resH,
              horizontal: 16.resW,
            ),
            child: Row(
              children: [
                _buildAvatarPicker(),
                SizedBox(width: 16.resW),
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText: 'Group Name',
                      hintStyle: AppTypography.body1.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      border: const UnderlineInputBorder(),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: AppColors.primary),
                      ),
                    ),
                    style: AppTypography.subtitle1,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: 16.resW,
              vertical: 8.resH,
            ),
            color: Colors.grey[100],
            child: Text(
              'SELECT CONTACTS',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<ChatSession>>(
              stream: context.read<ChatCubit>().watchLocalContacts,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final contacts = snapshot.data ?? [];

                if (contacts.isEmpty) {
                  return Center(
                    child: Text(
                      'No contacts found.',
                      style: AppTypography.body1.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: contacts.length,
                  itemBuilder: (context, index) {
                    final contact = contacts[index];
                    final isSelected = _selectedContactIds.contains(
                      contact.phoneNumber,
                    );
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primary.withValues(
                          alpha: 0.1,
                        ),
                        backgroundImage: contact.avatarUrl.isNotEmpty
                            ? CachedNetworkImageProvider(
                                UrlUtils.resolveMediaUrl(contact.avatarUrl),
                              )
                            : null,
                        child: contact.avatarUrl.isEmpty
                            ? Text(
                                contact.name.isNotEmpty
                                    ? contact.name[0].toUpperCase()
                                    : '?',
                                style: AppTypography.subtitle1.copyWith(
                                  color: AppColors.primary,
                                ),
                              )
                            : null,
                      ),
                      title: Text(contact.name, style: AppTypography.subtitle1),
                      subtitle: Text(
                        contact.phoneNumber,
                        style: AppTypography.body2.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      trailing: Checkbox(
                        value: isSelected,
                        onChanged: (_) => _toggleSelection(contact.phoneNumber),
                        activeColor: AppColors.primary,
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
