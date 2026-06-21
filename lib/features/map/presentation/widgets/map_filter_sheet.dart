import 'package:ciro_chat_app/core/theme/app_typography.dart';
import 'package:ciro_chat_app/features/map/domain/entities/map_filter.dart';
import 'package:ciro_chat_app/features/map/domain/entities/map_group.dart';
import 'package:ciro_chat_app/features/map/presentation/bloc/map_cubit.dart';
import 'package:ciro_chat_app/features/map/presentation/bloc/map_state.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class MapFilterSheet extends StatefulWidget {
  const MapFilterSheet({super.key});

  @override
  State<MapFilterSheet> createState() => _MapFilterSheetState();
}

class _MapFilterSheetState extends State<MapFilterSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _search = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MapCubit, MapState>(
      builder: (context, state) {
        final cubit = context.read<MapCubit>();
        final filter = state.filter;
        final filteredGroups = _search.isEmpty
            ? state.groups
            : state.groups
                .where((g) => g.name.toLowerCase().contains(_search))
                .toList();

        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF9F9F9),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
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
                Center(
                  child: Container(
                    width: 50,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDDDDDD),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'map_filter'.tr(),
                      style: AppTypography.headline2.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.black54),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Status Section
                _buildSectionCard(
                  child: Column(
                    children: [
                      _buildSectionHeader('map_filter_status'.tr(), Icons.person_outline),
                      const SizedBox(height: 8),
                      _buildStatusItem(
                        'map_filter_status_all'.tr(),
                        'Show all users on the map',
                        MapStatusFilter.all,
                        filter,
                        cubit,
                      ),
                      _buildStatusItem(
                        'map_filter_status_online'.tr(),
                        'Show online users only',
                        MapStatusFilter.online,
                        filter,
                        cubit,
                      ),
                      _buildStatusItem(
                        'map_filter_status_offline'.tr(),
                        'Show offline users only',
                        MapStatusFilter.offline,
                        filter,
                        cubit,
                        isLast: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Distance Section
                _buildSectionCard(
                  child: Column(
                    children: [
                      _buildSectionHeader('map_filter_distance'.tr(), Icons.near_me_outlined),
                      const SizedBox(height: 8),
                      _buildDistanceItem(
                        'map_all_locations'.tr(),
                        MapDistanceFilter.all,
                        filter,
                        cubit,
                      ),
                      _buildDistanceItem(
                        'map_nearby_only'.tr(),
                        MapDistanceFilter.nearby,
                        filter,
                        cubit,
                        isLast: true,
                        disabled: state.selfLocation == null,
                      ),
                      if (state.selfLocation == null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'map_nearby_needs_location'.tr(),
                          style: AppTypography.caption.copyWith(color: Colors.grey.shade500),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Groups Section
                _buildSectionCard(
                  child: Column(
                    children: [
                      _buildSectionHeader('map_filter_groups'.tr(), Icons.people_outline),
                      const SizedBox(height: 8),
                      _buildGroupItemRadio(
                        title: 'map_filter_status_all'.tr(),
                        subtitle: 'Show all Member on the map',
                        isSelected: filter.groupId == null,
                        onTap: () => cubit.setGroupFilter(null),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'map_filter_search'.tr(),
                            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                            prefixIcon: Icon(Icons.search, color: Colors.grey.shade400, size: 20),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...filteredGroups.map((group) {
                        final isLast = filteredGroups.last == group;
                        return _buildGroupAvatarItem(group, isLast, filter, cubit);
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: AppTypography.subtitle1.copyWith(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF555555),
          ),
        ),
        Icon(icon, color: Colors.grey.shade600, size: 22),
      ],
    );
  }

  Widget _buildStatusItem(
    String title,
    String subtitle,
    MapStatusFilter value,
    MapFilter filter,
    MapCubit cubit, {
    bool isLast = false,
  }) {
    final isSelected = filter.status == value;
    return InkWell(
      onTap: () => cubit.setStatusFilter(value),
      child: Padding(
        padding: EdgeInsets.only(bottom: isLast ? 0 : 16, top: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.body1.copyWith(fontWeight: FontWeight.w500, color: Colors.black87)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTypography.caption.copyWith(color: Colors.grey.shade500)),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? const Color(0xFF4CAF50) : Colors.grey.shade400,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistanceItem(
    String title,
    MapDistanceFilter value,
    MapFilter filter,
    MapCubit cubit, {
    bool isLast = false,
    bool disabled = false,
  }) {
    final isSelected = filter.distance == value;
    return InkWell(
      onTap: disabled ? null : () => cubit.setDistanceFilter(value),
      child: Padding(
        padding: EdgeInsets.only(bottom: isLast ? 0 : 12, top: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: AppTypography.body1.copyWith(
                  fontWeight: FontWeight.w500,
                  color: disabled ? Colors.grey.shade400 : Colors.black87,
                ),
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? const Color(0xFF4CAF50) : Colors.grey.shade400,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupItemRadio({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.body1.copyWith(fontWeight: FontWeight.w500, color: Colors.black87)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTypography.caption.copyWith(color: Colors.grey.shade500)),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? const Color(0xFF4CAF50) : Colors.grey.shade400,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupAvatarItem(
    MapGroup group,
    bool isLast,
    MapFilter filter,
    MapCubit cubit,
  ) {
    final isSelected = filter.groupId == group.id;
    return InkWell(
      onTap: () => cubit.setGroupFilter(group.id),
      child: Padding(
        padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFF1E3A5F),
              child: Text(
                group.initials,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(group.name, style: AppTypography.body1.copyWith(fontWeight: FontWeight.w500, color: Colors.black87)),
                  const SizedBox(height: 2),
                  Text('${group.memberCount} members', style: AppTypography.caption.copyWith(color: Colors.grey.shade500)),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? const Color(0xFF4CAF50) : Colors.grey.shade400,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}
