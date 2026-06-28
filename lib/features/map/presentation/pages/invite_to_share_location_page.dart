import 'package:ciro_chat_app/core/routing/app_router.dart';
import 'package:ciro_chat_app/core/theme/app_colors.dart';
import 'package:ciro_chat_app/core/theme/app_typography.dart';
import 'package:ciro_chat_app/core/utils/url_utils.dart';
import 'package:ciro_chat_app/features/chat/domain/entities/chat_session.dart';
import 'package:ciro_chat_app/features/chat/presentation/bloc/chat_cubit.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// "+person" on the map top bar (018-snap-map-realtime): pick a contact and
/// open a chat with them so the viewer can ask them to share their location
/// — reuses the same contact list / chat-room flow the Chats tab already
/// has, rather than inventing a separate invite mechanism.
class InviteToShareLocationPage extends StatelessWidget {
  const InviteToShareLocationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Invite to Share Location',
          style: AppTypography.headline2.copyWith(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
      ),
      body: StreamBuilder<List<ChatSession>>(
        stream: context.read<ChatCubit>().watchLocalContacts,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final currentUserId = context.read<ChatCubit>().currentUserId;
          final contacts = (snapshot.data ?? [])
              .where((c) => c.id != currentUserId)
              .toList();
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
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
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
                onTap: () {
                  context.pop();
                  context.push(
                    AppRouterName.chatRoom,
                    extra: ChatRoomLaunchArgs(
                      // id = '' signals the JIT path; contactUserId carries
                      // the contact's MongoDB User _id so ChatCubit can call
                      // createRoom(contactUserId) on first Send — same
                      // pattern as ContactsScreen._startPrivateChat.
                      contact.copyWith(id: '', contactUserId: contact.id),
                      initialDraftText: 'invite_share_location_draft'.tr(),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
