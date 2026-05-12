import 'package:ciro_chat_app/core/theme/app_colors.dart';
import 'package:ciro_chat_app/core/theme/app_constants.dart';
import 'package:ciro_chat_app/features/status/domain/entities/music_track.dart';
import 'package:ciro_chat_app/features/status/presentation/bloc/music_cubit.dart';
import 'package:ciro_chat_app/features/status/presentation/bloc/music_state.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class MusicSelectorSheet extends StatefulWidget {
  final ValueChanged<MusicTrack> onTrackSelected;

  const MusicSelectorSheet({super.key, required this.onTrackSelected});

  @override
  State<MusicSelectorSheet> createState() => _MusicSelectorSheetState();
}

class _MusicSelectorSheetState extends State<MusicSelectorSheet> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _selectedCategory;

  // Mock Categories for MVP
  final List<String> _categories = ['Suggestions', 'Mood', 'Type', 'Trending'];
  MusicTrack? _previewingTrack;

  @override
  void initState() {
    super.initState();
    context.read<MusicCubit>().loadTracks();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 50) {
        context.read<MusicCubit>().loadMore();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    context.read<MusicCubit>().searchTracks(query);
  }

  void _onCategoryTapped(String category) {
    setState(() {
      _selectedCategory = _selectedCategory == category ? null : category;
    });
    context.read<MusicCubit>().loadTracks(
          query: _searchController.text,
          category: _selectedCategory,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: AppConstants.sheetRadius,
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: AppConstants.spacingSm, bottom: AppConstants.spacingMd),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(AppConstants.radiusPill),
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingMd),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'status.search'.tr(),
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          const SizedBox(height: AppConstants.spacingMd),

          // Categories
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingMd),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppConstants.spacingSm),
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = category == _selectedCategory;
                return ChoiceChip(
                  label: Text(category),
                  selected: isSelected,
                  onSelected: (_) => _onCategoryTapped(category),
                  selectedColor: AppColors.primary.withOpacity(0.2),
                );
              },
            ),
          ),

          const SizedBox(height: AppConstants.spacingMd),

          // Track List
          Expanded(
            child: BlocBuilder<MusicCubit, MusicState>(
              builder: (context, state) {
                if (state is MusicLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else if (state is MusicError) {
                  return Center(child: Text(state.message));
                } else if (state is MusicLoaded) {
                  final tracks = state.tracks;
                  if (tracks.isEmpty) {
                    return Center(child: Text('status.no_music_found'.tr()));
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    itemCount: tracks.length + (state.hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == tracks.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(AppConstants.spacingMd),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      final track = tracks[index];
                      final isPreviewing = _previewingTrack?.id == track.id;

                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                          child: Image.network(
                            track.thumbnailUrl,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 50,
                              height: 50,
                              color: Colors.grey[300],
                              child: const Icon(Icons.music_note, color: Colors.grey),
                            ),
                          ),
                        ),
                        title: Text(track.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(track.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(isPreviewing ? Icons.stop_circle : Icons.play_circle_outline),
                              color: isPreviewing ? AppColors.primary : Colors.grey,
                              onPressed: () {
                                if (isPreviewing) {
                                  context.read<MusicCubit>().stopPreview();
                                  setState(() => _previewingTrack = null);
                                } else {
                                  context.read<MusicCubit>().previewTrack(track);
                                  setState(() => _previewingTrack = track);
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.check_circle_outline),
                              color: AppColors.primary,
                              onPressed: () {
                                context.read<MusicCubit>().stopPreview();
                                widget.onTrackSelected(track);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }
}
