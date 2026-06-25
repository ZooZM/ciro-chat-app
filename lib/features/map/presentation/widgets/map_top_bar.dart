import 'package:ciro_chat_app/core/theme/app_typography.dart';
import 'package:ciro_chat_app/features/map/presentation/bloc/map_state.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class MapTopBar extends StatelessWidget {
  const MapTopBar({
    super.key,
    required this.selectedTab,
    required this.onTabChanged,
    required this.onInvite,
    required this.onCreateGroup,
  });

  final MapTab selectedTab;
  final ValueChanged<MapTab> onTabChanged;
  final VoidCallback onInvite;
  final VoidCallback onCreateGroup;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          _GlassIconButton(
            icon: Icons.search,
            onTap: () {},
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Center(
              child: _FollowingExplorePill(
                selectedTab: selectedTab,
                onTabChanged: onTabChanged,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _GlassIconButton(
            icon: Icons.person_add_outlined,
            onTap: onInvite,
          ),
          const SizedBox(width: 8),
          _GlassIconButton(
            icon: Icons.add_box_outlined,
            onTap: onCreateGroup,
          ),
        ],
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: Colors.black87),
      ),
    );
  }
}

class _FollowingExplorePill extends StatelessWidget {
  const _FollowingExplorePill({
    required this.selectedTab,
    required this.onTabChanged,
  });

  final MapTab selectedTab;
  final ValueChanged<MapTab> onTabChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PillTab(
            label: 'map_following'.tr(),
            isSelected: selectedTab == MapTab.following,
            onTap: () => onTabChanged(MapTab.following),
          ),
          _PillTab(
            label: 'map_explore'.tr(),
            isSelected: selectedTab == MapTab.explore,
            onTap: () => onTabChanged(MapTab.explore),
          ),
        ],
      ),
    );
  }
}

class _PillTab extends StatelessWidget {
  const _PillTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.25)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
