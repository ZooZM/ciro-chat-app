import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ciro_chat_app/core/di/injection.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/creator_profile.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/reel.dart';
import 'package:ciro_chat_app/features/reels/presentation/bloc/creator_profile_cubit.dart';
import 'package:ciro_chat_app/features/reels/presentation/bloc/reels_feed_bloc.dart';
import 'package:ciro_chat_app/features/reels/presentation/bloc/reels_interaction_cubit.dart';
import 'package:ciro_chat_app/features/reels/presentation/widgets/follow_button.dart';
import 'package:ciro_chat_app/features/reels/presentation/widgets/reel_status_badge.dart';

/// Creator info, stats, and a 3-column video grid (FR-023–027). Tapping a
/// grid thumbnail opens the creator-scoped feed starting at that video.
/// When [userId] is the current user, gains owner-only Liked/Saved tabs
/// (US7/US8) and a Block entry point (FR-052).
class CreatorProfileScreen extends StatelessWidget {
  const CreatorProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<CreatorProfileCubit>()..load(userId),
      child: BlocBuilder<CreatorProfileCubit, CreatorProfileState>(
        builder: (context, state) {
          final profile = state.profile;
          return Scaffold(
            appBar: AppBar(
              elevation: 0,
              actions: [
                // v4: the upload entry point lives on the owner's own
                // profile screen only (not the Reels feed header).
                if (profile != null && profile.isSelf)
                  IconButton(
                    onPressed: () async {
                      final cubit = context.read<CreatorProfileCubit>();
                      final uploaded = await context.push<Reel?>('/reels/upload');
                      // A new reel is only visible to its owner (FR-061) and
                      // the main feed's shared bloc caches its list for the
                      // session (FR-004a) — both need an explicit nudge or
                      // the upload silently never shows up anywhere (FR-065).
                      if (uploaded != null) {
                        cubit.load(userId);
                        getIt<ReelsFeedBloc>().add(const ReelsRefreshRequested());
                      }
                    },
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: 'reels.upload_entry'.tr(),
                  ),
                if (profile != null && !profile.isSelf) _BlockMenu(profile: profile),
              ],
            ),
            body: switch (state.status) {
              CreatorProfileStatus.initial ||
              CreatorProfileStatus.loading =>
                const Center(child: CircularProgressIndicator()),
              CreatorProfileStatus.error => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('reels.profile_error'.tr()),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => context.read<CreatorProfileCubit>().load(userId),
                        child: Text('reels.retry'.tr()),
                      ),
                    ],
                  ),
                ),
              CreatorProfileStatus.ready => _ProfileBody(profile: profile!),
            },
          );
        },
      ),
    );
  }
}

class _BlockMenu extends StatelessWidget {
  const _BlockMenu({required this.profile});

  final CreatorProfile profile;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CreatorProfileCubit>();
    return PopupMenuButton<void>(
      itemBuilder: (context) => [
        PopupMenuItem(
          child: Text('reels.block_user'.tr()),
          onTap: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('reels.block_confirm_title'.tr()),
                content: Text('reels.block_confirm_body'.tr()),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text('reels.retry'.tr()),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text('reels.block_user'.tr()),
                  ),
                ],
              ),
            );
            if (confirmed != true) return;
            final blocked = await cubit.toggleBlock();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  blocked ? 'reels.blocked_notice'.tr() : 'reels.unblocked_notice'.tr(),
                ),
              ),
            );
            if (blocked) context.pop();
          },
        ),
      ],
    );
  }
}

class _ProfileBody extends StatefulWidget {
  const _ProfileBody({required this.profile});

  final CreatorProfile profile;

  @override
  State<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<_ProfileBody> with SingleTickerProviderStateMixin {
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    if (widget.profile.isSelf) {
      final controller = TabController(length: 3, vsync: this);
      controller.addListener(() {
        if (controller.indexIsChanging) return;
        final cubit = context.read<CreatorProfileCubit>();
        if (controller.index == 1) cubit.loadLikedTab();
        if (controller.index == 2) cubit.loadSavedTab();
      });
      _tabController = controller;
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final format = NumberFormat.compact();
    final header = SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            CircleAvatar(
              radius: 44,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: profile.avatarUrl.isEmpty
                  ? null
                  : CachedNetworkImageProvider(profile.avatarUrl),
              child: profile.avatarUrl.isEmpty ? const Icon(Icons.person, size: 40) : null,
            ),
            const SizedBox(height: 8),
            Text(profile.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            if (profile.username.isNotEmpty)
              Text('@${profile.username}', style: TextStyle(color: Colors.grey.shade600)),
            if (profile.bio.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                profile.bio,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
            const SizedBox(height: 16),
            FollowButton(creatorId: profile.id, isSelf: profile.isSelf),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Reactive (not the static initial fetch) so a follow
                // toggle on this screen — or earlier on the feed overlay
                // — is reflected here too (FR-030).
                BlocSelector<ReelsInteractionCubit, ReelsInteractionState, int>(
                  bloc: getIt<ReelsInteractionCubit>(),
                  selector: (state) =>
                      state.follows[profile.id]?.followersCount ?? profile.followersCount,
                  builder: (context, followersCount) => _StatColumn(
                    value: format.format(followersCount),
                    label: 'reels.profile_followers'.tr(),
                  ),
                ),
                const SizedBox(width: 32),
                _StatColumn(
                  value: format.format(profile.followingCount),
                  label: 'reels.profile_following'.tr(),
                ),
                const SizedBox(width: 32),
                _StatColumn(
                  value: format.format(profile.totalLikes),
                  label: 'reels.profile_likes'.tr(),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    final tabController = _tabController;
    if (tabController == null) {
      // Non-self profile: just the video grid, no tabs (owner-only privacy).
      return CustomScrollView(slivers: [header, _videoGridSliver(profile.id, profile.videos)]);
    }

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        header,
        SliverPersistentHeader(
          pinned: true,
          delegate: _TabBarDelegate(
            TabBar(
              controller: tabController,
              labelColor: Theme.of(context).colorScheme.onSurface,
              tabs: [
                Tab(text: 'reels.profile_tab_videos'.tr()),
                Tab(text: 'reels.profile_tab_liked'.tr()),
                Tab(text: 'reels.profile_tab_saved'.tr()),
              ],
            ),
          ),
        ),
      ],
      body: TabBarView(
        controller: tabController,
        children: [
          _VideosTab(profile: profile),
          BlocSelector<CreatorProfileCubit, CreatorProfileState, SelfTabState?>(
            selector: (state) => state.likedTab,
            builder: (context, tab) => _ReelListTab(
              tab: tab,
              listSource: 'liked',
              emptyKey: 'reels.liked_videos_empty',
            ),
          ),
          BlocSelector<CreatorProfileCubit, CreatorProfileState, SelfTabState?>(
            selector: (state) => state.savedTab,
            builder: (context, tab) => _ReelListTab(
              tab: tab,
              listSource: 'saved',
              emptyKey: 'reels.saved_videos_empty',
            ),
          ),
        ],
      ),
    );
  }

  Widget _videoGridSliver(String creatorId, List<dynamic> videos) {
    if (videos.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: Text('reels.profile_empty_videos'.tr())),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.all(2),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
          childAspectRatio: 9 / 16,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final video = videos[index];
            return GestureDetector(
              onTap: () => context.push('/reels/creator/$creatorId?start=${video.id}'),
              child: video.thumbnailUrl.isEmpty
                  ? Container(color: Colors.grey.shade300)
                  : CachedNetworkImage(imageUrl: video.thumbnailUrl, fit: BoxFit.cover),
            );
          },
          childCount: videos.length,
        ),
      ),
    );
  }
}

class _VideosTab extends StatelessWidget {
  const _VideosTab({required this.profile});

  final CreatorProfile profile;

  Future<void> _confirmDelete(BuildContext context, String reelId) async {
    final cubit = context.read<CreatorProfileCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('reels.delete_confirm_title'.tr()),
        content: Text('reels.delete_confirm_body'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('reels.retry'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('reels.delete_confirm_action'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final deleted = await cubit.deleteReel(reelId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(deleted ? 'reels.delete_success'.tr() : 'reels.delete_failed'.tr()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (profile.videos.isEmpty) {
      return Center(child: Text('reels.profile_empty_videos'.tr()));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 9 / 16,
      ),
      itemCount: profile.videos.length,
      itemBuilder: (context, index) {
        final video = profile.videos[index];
        return GestureDetector(
          onTap: () => context.push('/reels/creator/${profile.id}?start=${video.id}'),
          onLongPress: () => _confirmDelete(context, video.id),
          child: Stack(
            fit: StackFit.expand,
            children: [
              video.thumbnailUrl.isEmpty
                  ? Container(color: Colors.grey.shade300)
                  : CachedNetworkImage(imageUrl: video.thumbnailUrl, fit: BoxFit.cover),
              ReelStatusBadge(status: video.status),
            ],
          ),
        );
      },
    );
  }
}

/// FR-050/051: Liked/Saved tabs — owner-only, scoped feed entry per item
/// (US8 scenario 4).
class _ReelListTab extends StatelessWidget {
  const _ReelListTab({required this.tab, required this.listSource, required this.emptyKey});

  final SelfTabState? tab;
  final String listSource;
  final String emptyKey;

  @override
  Widget build(BuildContext context) {
    if (tab == null || tab!.status == SelfTabStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (tab!.status == SelfTabStatus.error) {
      return Center(child: Text('reels.action_failed'.tr()));
    }
    final videos = tab!.videos;
    if (videos.isEmpty) {
      return Center(child: Text(emptyKey.tr()));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 9 / 16,
      ),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final Reel video = videos[index];
        return GestureDetector(
          onTap: () => context.push('/reels/$listSource?start=${video.id}'),
          child: video.thumbnailUrl.isEmpty
              ? Container(color: Colors.grey.shade300)
              : CachedNetworkImage(imageUrl: video.thumbnailUrl, fit: BoxFit.cover),
        );
      },
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate(this.tabBar);

  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ColoredBox(color: Theme.of(context).scaffoldBackgroundColor, child: tabBar);
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => tabBar != oldDelegate.tabBar;
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }
}
