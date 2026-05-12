import 'package:ciro_chat_app/core/theme/app_colors.dart';
import 'package:ciro_chat_app/core/theme/app_typography.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_entity.dart';
import 'package:ciro_chat_app/features/status/presentation/widgets/status_tile.dart';
import 'package:ciro_chat_app/features/status/presentation/widgets/status_search_bar.dart';
import 'package:ciro_chat_app/features/status/presentation/pages/story_viewer_screen.dart';
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
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';
import 'package:easy_localization/easy_localization.dart';

class UpdatesScreen extends StatefulWidget {
  const UpdatesScreen({super.key});

  @override
  State<UpdatesScreen> createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends State<UpdatesScreen> {
  String _searchQuery = '';

  final StatusEntity _mockMyStatus = StatusEntity(
    id: '0',
    authorName: 'Me',
    authorAvatar: '',
    timestamp: DateTime.now(),
    expiresAt: DateTime.now().add(const Duration(hours: 24)),
    isViewed: true,
    isMine: true,
  );

  final List<StatusEntity> _mockRecentStatuses = [
    StatusEntity(
      id: '1',
      authorName: 'Alice Smith',
      authorAvatar: 'https://i.pravatar.cc/150?u=1',
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      expiresAt: DateTime.now().add(const Duration(hours: 23, minutes: 55)),
      isViewed: false,
      isMine: false,
    ),
    StatusEntity(
      id: '2',
      authorName: 'Bob Johnson',
      authorAvatar: 'https://i.pravatar.cc/150?u=2',
      timestamp: DateTime.now().subtract(const Duration(minutes: 45)),
      expiresAt: DateTime.now().add(const Duration(hours: 23, minutes: 15)),
      isViewed: false,
      isMine: false,
    ),
  ];

  final List<StatusEntity> _mockViewedStatuses = [
    StatusEntity(
      id: '3',
      authorName: 'Charlie Davis',
      authorAvatar: 'https://i.pravatar.cc/150?u=3',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      expiresAt: DateTime.now().add(const Duration(hours: 22)),
      isViewed: true,
      isMine: false,
    ),
  ];

  void _showAddStatusBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddStatusBottomSheet(
        onCameraTap: () async {
          Navigator.pop(context);
          final status = await Permission.camera.request();
          if (status.isGranted) {
            final picker = ImagePicker();
            final xfile = await picker.pickImage(source: ImageSource.camera);
            if (xfile != null && mounted) {
              // TODO: pass media to StatusCreationScreen via extra or cubit
              context.push('/status_creation', extra: StatusContentType.image);
            }
          }
        },
        onGalleryItemTap: (file, isVideo) async {
          Navigator.pop(context);
          if (isVideo) {
            final controller = VideoPlayerController.file(File(file.path));
            await controller.initialize();
            if (controller.value.duration.inSeconds > 30) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('status.video_too_long'.tr())),
                );
              }
              controller.dispose();
              return;
            }
            controller.dispose();
            if (mounted) {
              context.push('/status_creation', extra: StatusContentType.video);
            }
          } else {
            if (mounted) {
              context.push('/status_creation', extra: StatusContentType.image);
            }
          }
        },
        onCategoryTap: (mode) {
          Navigator.pop(context);
          context.push('/status_creation', extra: mode);
        },
        onMusicTap: () {
          Navigator.pop(context);
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (ctx) => BlocProvider.value(
              value: getIt<MusicCubit>(),
              child: MusicSelectorSheet(
                onTrackSelected: (track) {
                  Navigator.pop(ctx);
                  final cubit = getIt<StatusCreationCubit>();
                  cubit.initDraft(StatusContentType.text); // defaults to text for music
                  cubit.attachMusicTrack(track.id);
                  context.push('/status_creation', extra: StatusContentType.text);
                },
              ),
            ),
          );
        },
        onAITap: () {
          Navigator.pop(context);
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (ctx) => AIImageGeneratorSheet(
              onGenerate: (prompt) async {
                final cubit = getIt<StatusCreationCubit>();
                final resultOrError = await cubit.statusRepository.generateAIImage(prompt);
                return resultOrError.fold(
                  (l) => throw Exception(l.message),
                  (r) => r,
                );
              },
              onImageSelected: (imageUrl) {
                Navigator.pop(ctx);
                final cubit = getIt<StatusCreationCubit>();
                cubit.initDraft(StatusContentType.image);
                cubit.attachAIImage(imageUrl);
                context.push('/status_creation', extra: StatusContentType.image);
              },
              onVoicePromptTapped: () {
                // TODO: Voice to text logic
              },
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchQuery.toLowerCase();
    
    final filteredRecent = _mockRecentStatuses
        .where((s) => s.authorName.toLowerCase().contains(query))
        .toList();
        
    final filteredViewed = _mockViewedStatuses
        .where((s) => s.authorName.toLowerCase().contains(query))
        .toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
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
                  'Updates',
                  style: AppTypography.subtitle1.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: 12.resW),
                Expanded(
                  child: StatusSearchBar(
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: ListTile(
                    leading: Stack(
                      children: [
                        Container(
                          width: 56.resW,
                          height: 56.resW,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey, width: 2.resW),
                          ),
                          padding: EdgeInsets.all(2.resW),
                          child: CircleAvatar(
                            backgroundColor: Colors.grey[300],
                            child: Icon(Icons.person, color: Colors.white, size: 30.resW),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.add, color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                    ),
                    title: Text(
                      'My status',
                      style: AppTypography.subtitle1.copyWith(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Tap to add status update',
                      style: AppTypography.body2.copyWith(color: AppColors.textSecondary),
                    ),
                    onTap: _showAddStatusBottomSheet,
                  ),
                ),
                if (filteredRecent.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.resW, vertical: 8.resH),
                      child: Text(
                        'Recent updates',
                        style: AppTypography.subtitle2.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                if (filteredRecent.isNotEmpty)
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final status = filteredRecent[index];
                        return StatusTile(
                          status: status,
                          onTap: () {
                            context.push('/story_viewer', extra: status);
                          },
                        );
                      },
                      childCount: filteredRecent.length,
                    ),
                  ),
                if (filteredViewed.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.resW, vertical: 8.resH),
                      child: Text(
                        'Viewed updates',
                        style: AppTypography.subtitle2.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                if (filteredViewed.isNotEmpty)
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final status = filteredViewed[index];
                        return StatusTile(
                          status: status,
                          onTap: () {
                            context.push('/story_viewer', extra: status);
                          },
                        );
                      },
                      childCount: filteredViewed.length,
                    ),
                  ),
                if (filteredRecent.isEmpty && filteredViewed.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Text(
                        'No recent updates',
                        style: AppTypography.body1.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'pencil_fab',
            onPressed: () {
              _showAddStatusBottomSheet();
            },
            backgroundColor: Colors.grey[200],
            child: Icon(Icons.edit, color: AppColors.textPrimary),
          ),
          SizedBox(height: 16.resH),
          FloatingActionButton(
            heroTag: 'camera_fab',
            onPressed: () {
              // Prototype camera status
            },
            backgroundColor: AppColors.primary,
            child: const Icon(Icons.camera_alt, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
