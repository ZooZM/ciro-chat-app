import 'package:ciro_chat_app/core/theme/app_colors.dart';
import 'package:ciro_chat_app/core/theme/app_typography.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/map_cubit.dart';
import '../bloc/map_state.dart';

class MapFabColumn extends StatelessWidget {
  const MapFabColumn({
    super.key,
    required this.onFilterTap,
    required this.onLocateMe,
  });

  final VoidCallback onFilterTap;
  final VoidCallback onLocateMe;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _CircleFab(
          icon: Icons.layers_outlined,
          tooltip: 'map_layers'.tr(),
          onTap: () => context.read<MapCubit>().toggleMapType(),
        ),
        const SizedBox(height: 10),
        _CircleFab(
          icon: Icons.tune,
          tooltip: 'map_filter'.tr(),
          onTap: onFilterTap,
        ),
        const SizedBox(height: 10),
        _CircleFab(
          icon: Icons.my_location,
          tooltip: 'map_locate_me'.tr(),
          onTap: onLocateMe,
        ),
        const SizedBox(height: 16),
        const _ShareLocationFab(),
      ],
    );
  }
}

class _CircleFab extends StatelessWidget {
  const _CircleFab({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, size: 22, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

/// Tap toggles live location sharing; long-press toggles Ghost Mode
/// (FR-005/011) — reuses the existing single FAB rather than adding new UI.
class _ShareLocationFab extends StatelessWidget {
  const _ShareLocationFab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MapCubit, MapState>(
      buildWhen: (previous, current) =>
          previous.isSharing != current.isSharing ||
          previous.isGhostMode != current.isGhostMode,
      builder: (context, state) {
        final cubit = context.read<MapCubit>();
        final isGhost = state.isGhostMode;
        final color = isGhost ? Colors.grey.shade600 : AppColors.primary;

        return GestureDetector(
          onTap: () {
            if (isGhost) return;
            state.isSharing ? cubit.stopSharing() : cubit.startSharing();
          },
          onLongPress: cubit.toggleGhostMode,
          child: Tooltip(
            message: isGhost ? 'map_ghost_mode_on'.tr() : 'map_ghost_mode'.tr(),
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isGhost
                        ? Icons.visibility_off
                        : (state.isSharing ? Icons.location_on : Icons.location_off),
                    color: Colors.white,
                    size: 22,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isGhost ? 'map_ghost_mode'.tr() : 'map_share_location'.tr(),
                    style: AppTypography.caption.copyWith(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
