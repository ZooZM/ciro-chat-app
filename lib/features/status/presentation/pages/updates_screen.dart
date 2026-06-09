import 'package:cached_network_image/cached_network_image.dart';
import 'package:ciro_chat_app/core/theme/app_colors.dart';
import 'package:ciro_chat_app/core/theme/app_typography.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';
import 'package:ciro_chat_app/features/status/presentation/bloc/status_cubit.dart';
import 'package:ciro_chat_app/features/status/presentation/widgets/status_tile.dart';
import 'package:ciro_chat_app/features/status/presentation/widgets/status_search_bar.dart';
import 'package:ciro_chat_app/features/status/presentation/pages/story_viewer_screen.dart';
import 'package:ciro_chat_app/features/status/presentation/pages/reels_viewer_screen.dart';
import 'dart:io';
import 'package:ciro_chat_app/features/status/presentation/widgets/add_status_bottom_sheet.dart';
import 'package:ciro_chat_app/features/status/presentation/widgets/music_selector_sheet.dart';
import 'package:ciro_chat_app/features/status/presentation/widgets/ai_image_generator_sheet.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_content_type.dart';
import 'package:ciro_chat_app/core/di/injection.dart';
import 'package:ciro_chat_app/features/status/presentation/bloc/music_cubit.dart';
import 'package:ciro_chat_app/features/status/presentation/bloc/status_creation_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:easy_localization/easy_localization.dart';

class UpdatesScreen extends StatelessWidget {
  const UpdatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _UpdatesView();
  }
}

class _UpdatesView extends StatefulWidget {
  const _UpdatesView();

  @override
  State<_UpdatesView> createState() => _UpdatesViewState();
}

class _UpdatesViewState extends State<_UpdatesView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: BlocBuilder<StatusCubit, StatusState>(
        builder: (context, state) {
          if (state is StatusLoading || state is StatusInitial) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is StatusError) {
            return Center(
              child: Text(
                state.message,
                style: AppTypography.body1.copyWith(color: Colors.red),
              ),
            );
          }

          final loaded = state is StatusLoaded ? state : null;
          final query = loaded?.searchQuery.toLowerCase() ?? '';
          final recentStatuses = loaded?.recentStatuses ?? [];
          final viewedStatuses = loaded?.viewedStatuses ?? [];
          final myStatus = loaded?.myStatus;

          final filteredRecent = query.isEmpty
              ? recentStatuses
              : recentStatuses
                    .where((s) => s.authorName.toLowerCase().contains(query))
                    .toList();

          final filteredViewed = query.isEmpty
              ? viewedStatuses
              : viewedStatuses
                    .where((s) => s.authorName.toLowerCase().contains(query))
                    .toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 16.resW,
                  vertical: 8.resH,
                ),
                child: Row(
                  children: [
                    Text(
                      'nav_updates'.tr(),
                      style: AppTypography.subtitle1.copyWith(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 12.resW),
                    Expanded(
                      child: StatusSearchBar(
                        onChanged: (val) {
                          context.read<StatusCubit>().searchStatuses(val);
                        },
                      ),
                    ),
                    SizedBox(width: 8.resW),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ReelsViewerScreen(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.play_circle_outline,
                                color: Colors.white, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              'map_explore'.tr(),
                              style: AppTypography.caption.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    // ── My Status tile ──────────────────────────────────────
                    SliverToBoxAdapter(
                      child: ListTile(
                        leading: Stack(
                          children: [
                            Container(
                              width: 56.resW,
                              height: 56.resW,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: myStatus != null
                                      ? AppColors.primary
                                      : Colors.grey,
                                  width: 2.resW,
                                ),
                              ),
                              padding: EdgeInsets.all(2.resW),
                              child: CircleAvatar(
                                backgroundColor: Colors.grey[300],
                                backgroundImage:
                                    myStatus?.authorAvatar.isNotEmpty == true
                                    ? CachedNetworkImageProvider(
                                        myStatus!.authorAvatar,
                                      )
                                    : null,
                                child: myStatus?.authorAvatar.isNotEmpty != true
                                    ? Icon(
                                        Icons.person,
                                        color: Colors.white,
                                        size: 30.resW,
                                      )
                                    : null,
                              ),
                            ),
                            if (myStatus == null)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.add,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: Text(
                          'status_my_status'.tr(),
                          style: AppTypography.subtitle1.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          myStatus != null
                              ? 'status_tap_to_view'.tr()
                              : 'status_tap_to_add'.tr(),
                          style: AppTypography.body2.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        onTap: () {
                          if (myStatus != null) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => StoryViewerScreen(status: myStatus),
                              ),
                            );
                          }
                        },
                      ),
                    ),

                    // ── Recent updates ──────────────────────────────────────
                    if (filteredRecent.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.resW,
                            vertical: 8.resH,
                          ),
                          child: Text(
                            'status_recent_updates'.tr(),
                            style: AppTypography.subtitle2.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    if (filteredRecent.isNotEmpty)
                      SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final status = filteredRecent[index];
                          return StatusTile(
                            status: status,
                            onTap: () {
                              context.read<StatusCubit>().markStatusAsViewed(
                                status.id,
                              );
                            },
                          );
                        }, childCount: filteredRecent.length),
                      ),

                    // ── Viewed updates ──────────────────────────────────────
                    if (filteredViewed.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.resW,
                            vertical: 8.resH,
                          ),
                          child: Text(
                            'status_viewed_updates'.tr(),
                            style: AppTypography.subtitle2.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    if (filteredViewed.isNotEmpty)
                      SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final status = filteredViewed[index];
                          return StatusTile(
                            status: status,
                            onTap: () {
                              // Already viewed — navigate to story viewer
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => StoryViewerScreen(status: status),
                                ),
                              );
                            },
                          );
                        }, childCount: filteredViewed.length),
                      ),

                    // ── Empty state ─────────────────────────────────────────
                    if (filteredRecent.isEmpty && filteredViewed.isEmpty)
                      SliverFillRemaining(
                        child: Center(
                          child: Text(
                            'status_no_recent'.tr(),
                            style: AppTypography.body1.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'pencil_fab',
            onPressed: () {
              // Text status — future implementation
            },
            backgroundColor: Colors.grey[200],
            child: Icon(Icons.edit, color: AppColors.textPrimary),
          ),
          SizedBox(height: 16.resH),
          FloatingActionButton(
            heroTag: 'camera_fab',
            onPressed: () {
              // Camera status — future implementation
            },
            backgroundColor: AppColors.primary,
            child: const Icon(Icons.camera_alt, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
