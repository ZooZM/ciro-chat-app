import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ciro_chat_app/core/di/injection.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/reel.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/search_user.dart';
import 'package:ciro_chat_app/features/reels/presentation/bloc/search_cubit.dart';
import 'package:ciro_chat_app/features/reels/presentation/widgets/search_results_skeleton.dart';

/// FR-057–059: search reels by hashtag substring and users by name/username
/// substring — both groups shown side by side, block-filtered server-side.
class ReelsSearchScreen extends StatelessWidget {
  const ReelsSearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<SearchCubit>(),
      child: const _SearchScaffold(),
    );
  }
}

class _SearchScaffold extends StatefulWidget {
  const _SearchScaffold();

  @override
  State<_SearchScaffold> createState() => _SearchScaffoldState();
}

class _SearchScaffoldState extends State<_SearchScaffold> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'reels.search_hint'.tr(),
            border: InputBorder.none,
          ),
          onChanged: context.read<SearchCubit>().search,
        ),
      ),
      body: BlocBuilder<SearchCubit, SearchState>(
        builder: (context, state) {
          switch (state.status) {
            case SearchStatus.idle:
              return const SizedBox.shrink();
            case SearchStatus.loading:
              return const SearchResultsSkeleton();
            case SearchStatus.error:
              return Center(child: Text('reels.action_failed'.tr()));
            case SearchStatus.ready:
              if (state.videos.isEmpty && state.users.isEmpty) {
                return Center(child: Text('reels.search_empty'.tr()));
              }
              return ListView(
                children: [
                  if (state.users.isNotEmpty) ...[
                    _SectionHeader('reels.search_users'.tr()),
                    ...state.users.map((u) => _UserTile(user: u)),
                  ],
                  if (state.videos.isNotEmpty) ...[
                    _SectionHeader('reels.search_videos'.tr()),
                    _VideoGrid(videos: state.videos),
                  ],
                ],
              );
          }
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user});

  final SearchUser user;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.grey.shade200,
        backgroundImage: user.avatarUrl.isEmpty ? null : CachedNetworkImageProvider(user.avatarUrl),
        child: user.avatarUrl.isEmpty ? const Icon(Icons.person) : null,
      ),
      title: Text(user.name),
      subtitle: user.username.isEmpty ? null : Text('@${user.username}'),
      onTap: () => context.push('/reels/profile/${user.id}'),
    );
  }
}

class _VideoGrid extends StatelessWidget {
  const _VideoGrid({required this.videos});

  final List<Reel> videos;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 9 / 16,
      ),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final video = videos[index];
        return GestureDetector(
          onTap: () => context.push('/reels/${video.id}'),
          child: video.thumbnailUrl.isEmpty
              ? Container(color: Colors.grey.shade300)
              : CachedNetworkImage(imageUrl: video.thumbnailUrl, fit: BoxFit.cover),
        );
      },
    );
  }
}
