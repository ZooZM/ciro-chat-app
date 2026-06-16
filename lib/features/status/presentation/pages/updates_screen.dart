import 'package:ciro_chat_app/core/theme/app_colors.dart';
import 'package:ciro_chat_app/core/theme/app_typography.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_content_type.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_entity.dart';
import 'package:ciro_chat_app/features/status/presentation/bloc/status_cubit.dart';
import 'package:ciro_chat_app/features/status/presentation/pages/status_creation_screen.dart';
import 'package:ciro_chat_app/features/status/presentation/widgets/add_status_bottom_sheet.dart';
import 'package:ciro_chat_app/features/status/presentation/widgets/status_avatar_preview.dart';
import 'package:ciro_chat_app/features/status/presentation/widgets/status_tile.dart';
import 'package:ciro_chat_app/features/status/presentation/widgets/status_search_bar.dart';
import 'package:ciro_chat_app/features/status/presentation/pages/story_viewer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
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
          if (state is StatusError) {
            return Center(
              child: Text(
                state.message,
                style: AppTypography.body1.copyWith(color: Colors.red),
              ),
            );
          }

          final isConnecting = state is StatusLoading || state is StatusInitial;
          final loaded = state is StatusLoaded ? state : null;
          final query = loaded?.searchQuery.toLowerCase() ?? '';
          final myStatuses = loaded?.myStatuses ?? [];

          // One group per author, each sorted oldest-first so the story
          // viewer can page through all of that author's active statuses.
          final allGroups = (loaded?.statusGroups ?? const <String, List<StatusEntity>>{})
              .values
              .toList();

          final recentGroups = allGroups.where((g) => g.any((s) => !s.isViewed)).toList()
            ..sort((a, b) => b.last.timestamp.compareTo(a.last.timestamp));

          final viewedGroups = allGroups.where((g) => g.every((s) => s.isViewed)).toList()
            ..sort((a, b) => b.last.timestamp.compareTo(a.last.timestamp));

          final filteredRecent = query.isEmpty
              ? recentGroups
              : recentGroups
                    .where((g) => g.last.authorName.toLowerCase().contains(query))
                    .toList();

          final filteredViewed = query.isEmpty
              ? viewedGroups
              : viewedGroups
                    .where((g) => g.last.authorName.toLowerCase().contains(query))
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'nav_updates'.tr(),
                          style: AppTypography.subtitle1.copyWith(
                            color: Colors.black,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (isConnecting)
                          Text(
                            'status_connecting'.tr(),
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
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
                    //explore reels button - future implementation
                    // GestureDetector(
                    //   onTap: () {
                    //     Navigator.of(context).push(
                    //       MaterialPageRoute(
                    //         builder: (_) => const ReelsViewerScreen(),
                    //       ),
                    //     );
                    //   },
                    //   child: Container(
                    //     padding: const EdgeInsets.symmetric(
                    //       horizontal: 12,
                    //       vertical: 6,
                    //     ),
                    //     decoration: BoxDecoration(
                    //       color: AppColors.primary,
                    //       borderRadius: BorderRadius.circular(16),
                    //     ),
                    //     child: Row(
                    //       mainAxisSize: MainAxisSize.min,
                    //       children: [
                    //         const Icon(
                    //           Icons.play_circle_outline,
                    //           color: Colors.white,
                    //           size: 16,
                    //         ),
                    //         const SizedBox(width: 4),
                    //         Text(
                    //           'map_explore'.tr(),
                    //           style: AppTypography.caption.copyWith(
                    //             color: Colors.white,
                    //             fontWeight: FontWeight.w700,
                    //           ),
                    //         ),
                    //       ],
                    //     ),
                    //   ),
                    // ),
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
                                  color: myStatuses.isNotEmpty
                                      ? AppColors.primary
                                      : Colors.grey,
                                  width: 2.resW,
                                ),
                              ),
                              padding: EdgeInsets.all(2.resW),
                              child: StatusAvatarPreview(
                                status: myStatuses.isNotEmpty ? myStatuses.last : null,
                                size: 52.resW,
                              ),
                            ),
                            if (myStatuses.isEmpty)
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
                          myStatuses.isNotEmpty
                              ? 'status_tap_to_view'.tr()
                              : 'status_tap_to_add'.tr(),
                          style: AppTypography.body2.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        onTap: () {
                          if (myStatuses.isNotEmpty) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => StoryViewerScreen(
                                  statuses: myStatuses,
                                ),
                              ),
                            );
                          } else {
                            _openAddStatusSheet(context);
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
                          final group = filteredRecent[index];
                          return StatusTile(
                            status: group.last,
                            onTap: () => _openGroup(context, group),
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
                          final group = filteredViewed[index];
                          return StatusTile(
                            status: group.last,
                            onTap: () => _openGroup(context, group),
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
            onPressed: () => _openCreationScreen(
              context,
              mode: StatusContentType.text,
            ),
            backgroundColor: Colors.grey[200],
            child: Icon(Icons.edit, color: AppColors.textPrimary),
          ),
          SizedBox(height: 16.resH),
          FloatingActionButton(
            heroTag: 'camera_fab',
            onPressed: () => _captureFromCamera(context),
            backgroundColor: AppColors.primary,
            child: const Icon(Icons.camera_alt, color: Colors.white),
          ),
        ],
      ),
    );
  }

  /// Opens [StoryViewerScreen] for an author's full [group] of active
  /// statuses (already sorted oldest-first), starting at their first
  /// unviewed status — or the beginning, if all have been viewed.
  void _openGroup(BuildContext context, List<StatusEntity> group) {
    final initialIndex = group.indexWhere((s) => !s.isViewed);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StoryViewerScreen(
          statuses: group,
          initialIndex: initialIndex < 0 ? 0 : initialIndex,
        ),
      ),
    );
  }

  Future<void> _openCreationScreen(
    BuildContext context, {
    required StatusContentType mode,
    String? mediaPath,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StatusCreationScreen(
          initialMode: mode,
          initialMediaPath: mediaPath,
        ),
      ),
    );
  }

  Future<void> _captureFromCamera(BuildContext context) async {
    final xfile = await ImagePicker().pickImage(source: ImageSource.camera);
    if (xfile == null || !context.mounted) return;
    await _openCreationScreen(
      context,
      mode: StatusContentType.image,
      mediaPath: xfile.path,
    );
  }

  void _openAddStatusSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => AddStatusBottomSheet(
        onCameraTap: () async {
          Navigator.of(sheetContext).pop();
          await _captureFromCamera(context);
        },
        onGalleryItemTap: (file, isVideo) async {
          Navigator.of(sheetContext).pop();
          await _openCreationScreen(
            context,
            mode: isVideo ? StatusContentType.video : StatusContentType.image,
            mediaPath: file.path,
          );
        },
        onCategoryTap: (mode) async {
          Navigator.of(sheetContext).pop();
          await _openCreationScreen(context, mode: mode);
        },
        onMusicTap: () => Navigator.of(sheetContext).pop(),
        onAITap: () => Navigator.of(sheetContext).pop(),
      ),
    );
  }
}
