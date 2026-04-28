import 'package:ciro_chat_app/core/theme/app_colors.dart';
import 'package:ciro_chat_app/core/theme/app_typography.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_entity.dart';
import 'package:ciro_chat_app/features/status/presentation/widgets/status_tile.dart';
import 'package:ciro_chat_app/features/status/presentation/widgets/status_search_bar.dart';
import 'package:ciro_chat_app/features/status/presentation/pages/story_viewer_screen.dart';
import 'package:flutter/material.dart';

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
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const StoryViewerScreen(),
                        ),
                      );
                    },
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
                            // Prototype view status action
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
                            // Prototype viewed action
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
              // Prototype text status
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
