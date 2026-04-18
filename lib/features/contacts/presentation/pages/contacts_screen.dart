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

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({Key? key}) : super(key: key);

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  @override
  void initState() {
    super.initState();
    // Dispatch organic state request fully into Cubit
    context.read<ChatCubit>().syncContacts();
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
      body: BlocBuilder<ChatCubit, ChatState>(
        builder: (context, state) {
          if (state is ChatLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16.resH),
                  Text(
                    'Syncing Ciro Connect contacts...',
                    style: AppTypography.body1,
                  ),
                ],
              ),
            );
          }

          if (state is ChatError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  SizedBox(height: 16.resH),
                  Text('Sync failed', style: AppTypography.subtitle1),
                  Text(state.message, style: AppTypography.body2),
                  TextButton(
                    onPressed: () => context.read<ChatCubit>().syncContacts(),
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            );
          }

          if (state is ChatContactsSynced) {
            final contacts = state.syncedContacts;
            if (contacts.isEmpty) {
              return Center(
                child: Text(
                  'None of your contacts are on Ciro Connect yet.',
                  style: AppTypography.body1.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              );
            }

            return ListView.builder(
              itemCount: contacts.length,
              itemBuilder: (context, index) {
                final user = contacts[index];
                return ChatTileWidget(
                  chat: user,
                  onTap: () => _startPrivateChat(user),
                );
              },
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}
