import 'package:flutter/material.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';
import 'package:ciro_chat_app/core/theme/app_colors.dart';
import 'package:ciro_chat_app/core/theme/app_typography.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/chat_cubit.dart';

class GroupParticipantTile extends StatelessWidget {
  final String phoneNumber;
  final bool isAdmin;
  final bool isMe;
  final bool showRemoveAction;
  final VoidCallback? onRemove;

  const GroupParticipantTile({
    Key? key,
    required this.phoneNumber,
    this.isAdmin = false,
    this.isMe = false,
    this.showRemoveAction = false,
    this.onRemove,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 16.resW, vertical: 4.resH),
      leading: CircleAvatar(
        radius: 24.resR,
        backgroundColor: AppColors.primary.withOpacity(0.1),
        child: Text(
          phoneNumber.isNotEmpty ? phoneNumber.substring(phoneNumber.length - 1).toUpperCase() : '?',
          style: AppTypography.subtitle1.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: FutureBuilder<String>(
        future: context.read<ChatCubit>().getLocalContactName(phoneNumber),
        builder: (context, snapshot) {
          final displayName = snapshot.data ?? phoneNumber;
          return Text(
            isMe ? '$displayName (You)' : displayName,
            style: AppTypography.subtitle1.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          );
        },
      ),
      subtitle: isAdmin 
          ? Text(
              'Admin',
              style: AppTypography.caption.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
      trailing: showRemoveAction && !isMe
          ? IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
              onPressed: onRemove,
            )
          : null,
    );
  }
}
