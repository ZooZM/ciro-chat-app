import 'package:ciro_chat_app/core/theme/app_colors.dart';
import 'package:ciro_chat_app/core/theme/app_typography.dart';
import 'package:ciro_chat_app/features/map/presentation/mock/map_mock_data.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class MapFilterSheet extends StatefulWidget {
  const MapFilterSheet({super.key});

  @override
  State<MapFilterSheet> createState() => _MapFilterSheetState();
}

class _MapFilterSheetState extends State<MapFilterSheet> {
  final TextEditingController _searchController = TextEditingController();
  StatusFilter _selectedStatus = StatusFilter.all;
  final Set<String> _selectedGroups = {};
  double _maxDistanceKm = 50;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 16,
        right: 16,
        top: 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDDDDDD),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'map_filter'.tr(),
            style: AppTypography.subtitle1.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'map_filter_search'.tr(),
              hintStyle: AppTypography.body2,
              prefixIcon: const Icon(Icons.search, color: Color(0xFF9E9E9E)),
              filled: true,
              fillColor: const Color(0xFFF5F5F5),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),
          // Status section
          Text(
            'map_filter_status'.tr(),
            style: AppTypography.subtitle2.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          ...[
            (StatusFilter.all, 'map_filter_status_all'.tr()),
            (StatusFilter.online, 'map_filter_status_online'.tr()),
            (StatusFilter.offline, 'map_filter_status_offline'.tr()),
          ].map((entry) {
            final isSelected = _selectedStatus == entry.$1;
            return InkWell(
              onTap: () => setState(() => _selectedStatus = entry.$1),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: isSelected ? AppColors.primary : const Color(0xFF9E9E9E),
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Text(entry.$2, style: AppTypography.body2),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 4),
          const Divider(height: 1),
          const SizedBox(height: 16),
          // Groups section
          Text(
            'map_filter_groups'.tr(),
            style: AppTypography.subtitle2.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: mockGroups.map((group) {
              final isSelected = _selectedGroups.contains(group);
              return FilterChip(
                label: Text(
                  group,
                  style: AppTypography.caption.copyWith(
                    color:
                        isSelected ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                selected: isSelected,
                selectedColor: AppColors.primary,
                backgroundColor: const Color(0xFFF0F0F0),
                checkmarkColor: Colors.white,
                side: BorderSide.none,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedGroups.add(group);
                    } else {
                      _selectedGroups.remove(group);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          // Distance section
          Row(
            children: [
              Text(
                'map_filter_distance'.tr(),
                style: AppTypography.subtitle2.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${_maxDistanceKm.toStringAsFixed(0)} km',
                style: AppTypography.body2.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Slider(
            min: 0,
            max: 100,
            value: _maxDistanceKm,
            activeColor: AppColors.primary,
            inactiveColor: AppColors.primaryLight,
            onChanged: (val) => setState(() => _maxDistanceKm = val),
          ),
          const SizedBox(height: 16),
          // Apply button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'map_filter_apply'.tr(),
                style: AppTypography.buttonText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
