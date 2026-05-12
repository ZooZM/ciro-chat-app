import 'package:ciro_chat_app/core/theme/app_colors.dart';
import 'package:ciro_chat_app/core/theme/app_constants.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_content_type.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';

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
  // In a real app, you might use a package like `photo_manager` for a robust gallery grid.
  // For this MVP, we use ImagePicker to pick a file, but the design calls for a grid.
  // Since we only have image_picker, we will show a placeholder or call image_picker directly when a "Gallery" button is tapped.
  // Alternatively, if we need a grid, we can just show a button for "Open Gallery" for MVP.
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: AppConstants.sheetRadius,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40.w,
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'status.add_status'.tr(),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
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
                  icon: Icons.text_fields,
                  label: 'status.text'.tr(),
                  onTap: () => widget.onCategoryTap(StatusContentType.text),
                ),
                SizedBox(width: AppConstants.spacingSm),
                _buildCategoryChip(
                  icon: Icons.music_note,
                  label: 'status.music'.tr(),
                  onTap: widget.onMusicTap,
                ),
                SizedBox(width: AppConstants.spacingSm),
                _buildCategoryChip(
                  icon: Icons.mic,
                  label: 'status.voice'.tr(),
                  onTap: () => widget.onCategoryTap(StatusContentType.voice),
                ),
                SizedBox(width: AppConstants.spacingSm),
                _buildCategoryChip(
                  icon: Icons.auto_awesome,
                  label: 'status.ai_image'.tr(),
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
                'status.recently_used'.tr(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          
          SizedBox(height: AppConstants.spacingMd),
          
          // Gallery Grid / Camera Tile (Simplified for MVP using ImagePicker direct actions)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingMd),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: widget.onCameraTap,
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                    child: Container(
                      height: 100.h,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.camera_alt, size: 32),
                          SizedBox(height: AppConstants.spacingSm),
                          Text('status.camera'.tr()),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: AppConstants.spacingMd),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picker = ImagePicker();
                      final xfile = await picker.pickImage(source: ImageSource.gallery);
                      if (xfile != null) {
                        widget.onGalleryItemTap(xfile, false);
                      }
                    },
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                    child: Container(
                      height: 100.h,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.photo_library, size: 32),
                          SizedBox(height: AppConstants.spacingSm),
                          Text('status.image'.tr()),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(height: AppConstants.spacingXxl),
        ],
      ),
    );
  }

  Widget _buildCategoryChip({required IconData icon, required String label, required VoidCallback onTap}) {
    return ActionChip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      onPressed: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusPill),
      ),
      backgroundColor: Colors.grey.withOpacity(0.1),
    );
  }
}
