import 'dart:typed_data';

import 'package:ciro_chat_app/core/theme/app_colors.dart';
import 'package:ciro_chat_app/core/theme/app_constants.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_content_type.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';

class AddStatusBottomSheet extends StatefulWidget {
  final VoidCallback onCameraTap;
  final Function(XFile file, bool isVideo) onGalleryItemTap;
  final Function(StatusContentType mode) onCategoryTap;
  final VoidCallback onMusicTap;
  final VoidCallback onAITap;

  const AddStatusBottomSheet({
    super.key,
    required this.onCameraTap,
    required this.onGalleryItemTap,
    required this.onCategoryTap,
    required this.onMusicTap,
    required this.onAITap,
  });

  @override
  State<AddStatusBottomSheet> createState() => _AddStatusBottomSheetState();
}

class _AddStatusBottomSheetState extends State<AddStatusBottomSheet> {
  static const int _pageSize = 60;

  final ScrollController _scrollController = ScrollController();
  List<AssetEntity> _assets = [];
  AssetPathEntity? _assetPath;
  int _page = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadRecentAssets();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 400) {
      _loadMoreAssets();
    }
  }

  Future<void> _loadRecentAssets() async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.hasAccess) {
      if (!mounted) return;
      setState(() {
        _permissionDenied = true;
        _loading = false;
      });
      return;
    }

    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      onlyAll: true,
    );
    if (paths.isEmpty) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }

    _assetPath = paths.first;
    final assets = await _assetPath!.getAssetListPaged(page: 0, size: _pageSize);

    if (!mounted) return;
    setState(() {
      _assets = assets;
      _page = 0;
      _hasMore = assets.length == _pageSize;
      _loading = false;
    });
  }

  Future<void> _loadMoreAssets() async {
    if (_assetPath == null) return;
    _loadingMore = true;
    final nextPage = _page + 1;
    final assets = await _assetPath!.getAssetListPaged(page: nextPage, size: _pageSize);

    if (!mounted) return;
    setState(() {
      _assets.addAll(assets);
      _page = nextPage;
      _hasMore = assets.length == _pageSize;
      _loadingMore = false;
    });
  }

  Future<void> _onAssetTap(AssetEntity asset) async {
    final file = await asset.file;
    if (file == null) return;
    widget.onGalleryItemTap(XFile(file.path), asset.type == AssetType.video);
  }

  Future<void> _pickFromNativeGallery() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery);
    if (xfile != null) {
      widget.onGalleryItemTap(xfile, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 50.w,
            height: 4.h,
            margin: EdgeInsets.only(top: AppConstants.spacingSm, bottom: AppConstants.spacingMd),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(AppConstants.radiusPill),
            ),
          ),
          
          // Title Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingMd),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Text(
                    'Add Status', // Using literal string to match mockup exactly
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.black54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(height: AppConstants.spacingMd),
          
          // Category Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingMd),
            child: Row(
              children: [
                _buildCategoryChip(
                  icon: Icons.edit_outlined, // Text is a pencil icon in the mockup
                  iconColor: Colors.green,
                  label: 'Text',
                  onTap: () => widget.onCategoryTap(StatusContentType.text),
                ),
                SizedBox(width: AppConstants.spacingSm),
                _buildCategoryChip(
                  icon: Icons.music_note,
                  iconColor: Colors.green,
                  label: 'Music',
                  onTap: widget.onMusicTap,
                ),
                SizedBox(width: AppConstants.spacingSm),
                _buildCategoryChip(
                  icon: Icons.mic_none,
                  iconColor: Colors.green,
                  label: 'voice',
                  onTap: () => widget.onCategoryTap(StatusContentType.voice),
                ),
                SizedBox(width: AppConstants.spacingSm),
                _buildCategoryChip(
                  icon: Icons.auto_awesome,
                  iconColor: Colors.grey, // Ai icon color is grey in mockup
                  label: 'Ai image',
                  onTap: widget.onAITap,
                ),
              ],
            ),
          ),
          
          SizedBox(height: AppConstants.spacingLg),
          
          // Recently Used Label
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingMd),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Gallery',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.black54,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
          ),
          
          SizedBox(height: AppConstants.spacingMd),
          
          // Gallery Grid / Camera Tile
          Expanded(
            child: GridView.builder(
              controller: _scrollController,
              padding: EdgeInsets.zero,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 2.0,
                mainAxisSpacing: 2.0,
              ),
              itemCount: _loading ? 13 : (_permissionDenied ? 2 : 1 + _assets.length),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return InkWell(
                    onTap: widget.onCameraTap,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          right: BorderSide(color: Colors.grey.shade100, width: 2),
                          bottom: BorderSide(color: Colors.grey.shade100, width: 2),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.camera_alt_outlined, size: 28, color: Colors.green),
                          SizedBox(height: AppConstants.spacingXs),
                          const Text('Camera', style: TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  );
                }

                if (_loading || _permissionDenied) {
                  return InkWell(
                    onTap: _permissionDenied ? _pickFromNativeGallery : null,
                    child: Container(
                      color: Colors.grey.shade200,
                      child: Icon(Icons.image, color: Colors.grey.shade400, size: 32),
                    ),
                  );
                }

                final asset = _assets[index - 1];
                return InkWell(
                  onTap: () => _onAssetTap(asset),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      FutureBuilder<Uint8List?>(
                        future: asset.thumbnailDataWithSize(const ThumbnailSize.square(200)),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState != ConnectionState.done) {
                            return Container(color: Colors.grey.shade200);
                          }
                          final bytes = snapshot.data;
                          if (bytes == null) {
                            return Container(
                              color: Colors.grey.shade200,
                              child: Icon(Icons.broken_image, color: Colors.grey.shade400, size: 32),
                            );
                          }
                          return Image.memory(bytes, fit: BoxFit.cover);
                        },
                      ),
                      if (asset.type == AssetType.video)
                        const Positioned(
                          bottom: 4,
                          right: 4,
                          child: Icon(Icons.videocam, color: Colors.white, size: 18),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip({required IconData icon, required String label, required VoidCallback onTap, Color iconColor = AppColors.primary}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 80.w,
        padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingMd),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: iconColor),
            SizedBox(height: AppConstants.spacingXs),
            Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
