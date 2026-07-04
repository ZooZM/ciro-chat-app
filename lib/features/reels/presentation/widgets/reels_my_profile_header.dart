import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ciro_chat_app/core/di/injection.dart';
import 'package:ciro_chat_app/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:ciro_chat_app/features/reels/presentation/bloc/creator_profile_cubit.dart';
import 'package:ciro_chat_app/features/reels/presentation/pages/creator_profile_screen.dart';

/// Floating header for the main (tab-embedded, unscoped) Reels feed: the
/// logged-in user's own avatar on the far left (→ their Creator Profile,
/// which also hosts the upload entry point) and a search icon on the far
/// right. Mutually exclusive with the back button shown on pushed/scoped
/// feed instances (see [ReelsFeedScreen]).
class ReelsMyProfileHeader extends StatefulWidget {
  const ReelsMyProfileHeader({super.key});

  @override
  State<ReelsMyProfileHeader> createState() => _ReelsMyProfileHeaderState();
}

class _ReelsMyProfileHeaderState extends State<ReelsMyProfileHeader> {
  String? _userId;
  CreatorProfileCubit? _cubit;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = await getIt<AuthLocalDataSource>().getUserId();
    if (!mounted || userId == null || userId.isEmpty) return;
    final cubit = getIt<CreatorProfileCubit>()..load(userId);
    setState(() {
      _userId = userId;
      _cubit = cubit;
    });
  }

  @override
  void dispose() {
    _cubit?.close();
    super.dispose();
  }

  void _openMyProfile() {
    final userId = _userId;
    if (userId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CreatorProfileScreen(userId: userId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = _cubit;
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: _userId == null ? null : _openMyProfile,
          child: cubit == null
              ? const _MyAvatar(avatarUrl: '')
              : BlocBuilder<CreatorProfileCubit, CreatorProfileState>(
                  bloc: cubit,
                  builder: (context, state) =>
                      _MyAvatar(avatarUrl: state.profile?.avatarUrl ?? ''),
                ),
        ),
        // FR-057: opens Search — reels by hashtag, users by name (US9).
        GestureDetector(
          onTap: () => context.push('/reels/search'),
          child: const Icon(Icons.search, color: Colors.white, size: 26),
        ),
      ],
    );
  }
}

class _MyAvatar extends StatelessWidget {
  const _MyAvatar({required this.avatarUrl});

  final String avatarUrl;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 18,
      backgroundColor: Colors.grey.shade800,
      backgroundImage: avatarUrl.isEmpty
          ? null
          : CachedNetworkImageProvider(avatarUrl),
      child: avatarUrl.isEmpty
          ? const Icon(Icons.person, color: Colors.white70, size: 18)
          : null,
    );
  }
}
