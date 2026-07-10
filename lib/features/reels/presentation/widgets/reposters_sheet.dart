import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ciro_chat_app/core/di/injection.dart';
import 'package:ciro_chat_app/core/theme/app_colors.dart';
import 'package:ciro_chat_app/core/theme/app_typography.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/followed_user.dart';
import 'package:ciro_chat_app/features/reels/domain/repositories/reels_repository.dart';

/// v6: opens the reposters bottom sheet for [reelId] — everyone who reposted
/// the video, avatar + name only (no timestamp/Reply/Remove/heart). Tapping a
/// row opens that user's profile. Modal overlay, so the video keeps playing.
Future<void> showRepostersSheet(BuildContext context, String reelId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RepostersSheet(reelId: reelId),
  );
}

class _RepostersSheet extends StatefulWidget {
  const _RepostersSheet({required this.reelId});

  final String reelId;

  @override
  State<_RepostersSheet> createState() => _RepostersSheetState();
}

class _RepostersSheetState extends State<_RepostersSheet> {
  final _reposters = <FollowedUser>[];
  String? _nextCursor;
  bool _loading = true;
  bool _loadingMore = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await getIt<ReelsRepository>().fetchReposters(widget.reelId);
    if (!mounted) return;
    result.fold(
      (_) => setState(() {
        _loading = false;
        _failed = true;
      }),
      (page) => setState(() {
        _loading = false;
        _reposters.addAll(page.items);
        _nextCursor = page.nextCursor;
      }),
    );
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _nextCursor == null) return;
    setState(() => _loadingMore = true);
    final result = await getIt<ReelsRepository>()
        .fetchReposters(widget.reelId, cursor: _nextCursor);
    if (!mounted) return;
    result.fold(
      (_) => setState(() => _loadingMore = false),
      (page) => setState(() {
        _loadingMore = false;
        _reposters.addAll(page.items);
        _nextCursor = page.nextCursor;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, sheetScrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'reels.reposters_sheet_title'.tr(),
                  style: AppTypography.body1.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const Divider(height: 1),
              Expanded(child: _body(sheetScrollController)),
            ],
          ),
        );
      },
    );
  }

  Widget _body(ScrollController sheetScrollController) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_failed) {
      return Center(child: Text('reels.action_failed'.tr()));
    }
    if (_reposters.isEmpty) {
      return Center(child: Text('reels.reposted_videos_empty'.tr()));
    }
    return ListView.builder(
      controller: sheetScrollController,
      itemCount: _reposters.length + (_loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _reposters.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        // Trigger load-more as the tail approaches — deferred to after the
        // frame so it never calls setState during build.
        if (index >= _reposters.length - 5 && !_loadingMore && _nextCursor != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _loadMore());
        }
        final user = _reposters[index];
        final avatar = user.avatarUrl ?? '';
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.surfaceVariant,
            backgroundImage: avatar.isEmpty ? null : CachedNetworkImageProvider(avatar),
            child: avatar.isEmpty
                ? const Icon(Icons.person, color: AppColors.textSecondary)
                : null,
          ),
          title: Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: user.username.isEmpty
              ? null
              : Text('@${user.username}', maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () {
            Navigator.of(context).pop();
            context.push('/reels/profile/${user.id}');
          },
        );
      },
    );
  }
}
