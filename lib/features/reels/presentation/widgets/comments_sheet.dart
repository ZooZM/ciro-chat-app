import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ciro_chat_app/core/di/injection.dart';
import 'package:ciro_chat_app/core/theme/app_colors.dart';
import 'package:ciro_chat_app/core/theme/app_typography.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/reel_comment.dart';
import 'package:ciro_chat_app/features/reels/presentation/bloc/comments_cubit.dart';

/// Opens the lightweight comments bottom sheet for [reelId] (FR-019). The
/// caller's video keeps playing behind it — this is a modal overlay, not a
/// route push, so nothing feed-scoped rebuilds.
Future<void> showCommentsSheet(BuildContext context, String reelId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BlocProvider(
      create: (_) => getIt<CommentsCubit>()..load(reelId),
      child: const CommentsSheet(),
    ),
  );
}

class CommentsSheet extends StatefulWidget {
  const CommentsSheet({super.key});

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    context.read<CommentsCubit>().post(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'reels.comments_title'.tr(),
                    style: AppTypography.subtitle1,
                  ),
                ),
                const Divider(height: 1, color: AppColors.divider),
                Expanded(
                  child: BlocBuilder<CommentsCubit, CommentsState>(
                    builder: (context, state) {
                      if (state.status == CommentsStatus.loading ||
                          state.status == CommentsStatus.initial) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        );
                      }
                      if (state.status == CommentsStatus.error) {
                        return Center(
                          child: Text(
                            'reels.action_failed'.tr(),
                            style: AppTypography.body2.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        );
                      }
                      if (state.comments.isEmpty) {
                        return Center(
                          child: Text(
                            'reels.comments_empty'.tr(),
                            style: AppTypography.body2.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        );
                      }
                      return ListView.builder(
                        controller: scrollController,
                        itemCount: state.comments.length,
                        itemBuilder: (context, index) =>
                            _CommentTile(comment: state.comments[index]),
                      );
                    },
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: BlocBuilder<CommentsCubit, CommentsState>(
                      buildWhen: (previous, current) =>
                          previous.posting != current.posting,
                      builder: (context, state) {
                        return Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                enabled: !state.posting,
                                style: AppTypography.body2,
                                decoration: InputDecoration(
                                  hintText: 'reels.comment_hint'.tr(),
                                  hintStyle: AppTypography.body2.copyWith(
                                    color: AppColors.textHint,
                                  ),
                                  filled: true,
                                  fillColor: AppColors.surfaceVariant,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                ),
                                onSubmitted: (_) => _submit(context),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: state.posting
                                  ? null
                                  : () => _submit(context),
                              icon: const Icon(Icons.send),
                              color: AppColors.primary,
                              disabledColor: AppColors.textHint,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});

  final ReelComment comment;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.surfaceVariant,
        backgroundImage: comment.authorAvatarUrl.isEmpty
            ? null
            : CachedNetworkImageProvider(comment.authorAvatarUrl),
        child: comment.authorAvatarUrl.isEmpty
            ? const Icon(Icons.person, color: AppColors.textSecondary)
            : null,
      ),
      title: Text(
        comment.authorName,
        style: AppTypography.subtitle2.copyWith(color: AppColors.textPrimary),
      ),
      subtitle: Text(
        comment.text,
        style: AppTypography.body2.copyWith(color: AppColors.textPrimary),
      ),
    );
  }
}
