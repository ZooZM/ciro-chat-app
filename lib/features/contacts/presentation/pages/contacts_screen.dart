import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../chat/domain/entities/chat_session.dart';
import '../../../chat/presentation/widgets/chat_tile_widget.dart';
import '../../../chat/presentation/bloc/chat_cubit.dart';
import '../../data/contacts_service.dart';
import '../../../../core/di/injection.dart';

import 'package:permission_handler/permission_handler.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({Key? key}) : super(key: key);

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  bool _hasPermission = true;

  @override
  void initState() {
    super.initState();
    // Dispatch silent network fetch purely evaluating permission cleanly without UI destruction
    context.read<ChatCubit>().silentSyncContacts().then((granted) {
      if (mounted && !granted) {
        setState(() => _hasPermission = false);
      }
    });
  }

  Future<void> _startPrivateChat(ChatSession targetUser) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      debugPrint(
        '[ContactsScreen] Starting chat with ${targetUser.phoneNumber}',
      );
      final roomId = await getIt<ContactsService>().resolvePrivateChat(
        targetPhoneNumber: targetUser
            .phoneNumber, // targetUser.id = phoneNumber from sync-contacts
        chatSession: targetUser,
      );

      if (mounted) Navigator.pop(context); // dismiss loader

      final roomPayload = ChatSession(
        id: roomId,
        name: targetUser.name,
        lastMessage: '',
        timestamp: DateTime.now(),
        avatarUrl: targetUser.avatarUrl,
        isOnline: targetUser.isOnline,
        phoneNumber: targetUser.phoneNumber,
      );

      if (mounted) context.pushReplacement('/chat_room', extra: roomPayload);
    } catch (err) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to start chat: $err')));
      }
    }
  }

  Widget _buildPermissionDenied() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.resW),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.perm_contact_calendar, size: 60.resW, color: Colors.grey),
            SizedBox(height: 16.resH),
            Text(
              'We need access to your contacts to automatically connect you with your friends on Ciro Connect.',
              textAlign: TextAlign.center,
              style: AppTypography.subtitle1,
            ),
            SizedBox(height: 24.resH),
            ElevatedButton(
              onPressed: () => openAppSettings(),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Open Settings', style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    return ListView.separated(
      itemCount: 8,
      separatorBuilder: (context, index) => Divider(height: 1, indent: 80.resW),
      itemBuilder: (context, index) => ListTile(
        leading: CircleAvatar(backgroundColor: Colors.grey[200], radius: 24.resW),
        title: Container(height: 14.resH, width: double.infinity, color: Colors.grey[200]),
        subtitle: Container(height: 12.resH, width: 100.resW, color: Colors.grey[200]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Select Contact',
          style: AppTypography.headline2.copyWith(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black, size: 24.resW),
          onPressed: () => context.pop(),
        ),
      ),
      body: !_hasPermission
          ? _buildPermissionDenied()
          : StreamBuilder<List<ChatSession>>(
              stream: context.read<ChatCubit>().watchLocalContacts,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return _buildShimmer();
                }

                final contacts = snapshot.data ?? [];

                if (contacts.isEmpty) {
                  return Center(
                    child: Text(
                      'None of your contacts are on Ciro Connect yet.\nInvite them to join!',
                      textAlign: TextAlign.center,
                      style: AppTypography.body1.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: contacts.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: AppColors.divider.withOpacity(0.5),
                    indent: 80.resW,
                  ),
                  itemBuilder: (context, index) {
                    final user = contacts[index];
                    return ChatTileWidget(
                      chat: user,
                      onTap: () => _startPrivateChat(user),
                      currentUserId: context.read<ChatCubit>().currentUserId,
                    );
                  },
                );
              },
            ),
    );
  }
}
