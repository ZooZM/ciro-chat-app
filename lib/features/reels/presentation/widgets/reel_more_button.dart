import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ciro_chat_app/core/di/injection.dart';
import 'package:ciro_chat_app/core/theme/app_colors.dart';
import 'package:ciro_chat_app/core/theme/app_constants.dart';
import 'package:ciro_chat_app/core/theme/app_typography.dart';
import 'package:ciro_chat_app/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/reel.dart';
import 'package:ciro_chat_app/features/reels/domain/repositories/reels_repository.dart';
import 'package:ciro_chat_app/features/reels/presentation/bloc/reels_interaction_cubit.dart';
import 'report_reasons_sheet.dart';

/// Three-dot "more options" entry in the interaction column (TikTok-style,
/// FR-067/FR-068). Rendered for every viewer since v4 — the sheet's content
/// is ownership-gated instead: everyone sees Save/Unsave (relocated from
/// the action column, FR-068), plus Report (non-owner) or Delete (owner).
class ReelMoreButton extends StatefulWidget {
  const ReelMoreButton({super.key, required this.reel});

  final Reel reel;

  @override
  State<ReelMoreButton> createState() => _ReelMoreButtonState();
}

class _ReelMoreButtonState extends State<ReelMoreButton> {
  bool _isOwner = false;

  @override
  void initState() {
    super.initState();
    _checkOwnership();
  }

  Future<void> _checkOwnership() async {
    final userId = await getIt<AuthLocalDataSource>().getUserId();
    if (!mounted) return;
    setState(
      () => _isOwner = userId != null && userId == widget.reel.creator.id,
    );
  }

  Future<void> _openSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MoreOptionsSheet(reel: widget.reel, isOwner: _isOwner),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _openSheet,
      child: const Icon(
        Icons.more_horiz,
        color: Colors.white,
        size: 34,
        shadows: [Shadow(color: Colors.white, blurRadius: 8)],
      ),
    );
  }
}

class _MoreOptionsSheet extends StatefulWidget {
  const _MoreOptionsSheet({required this.reel, required this.isOwner});

  final Reel reel;
  final bool isOwner;

  @override
  State<_MoreOptionsSheet> createState() => _MoreOptionsSheetState();
}

class _MoreOptionsSheetState extends State<_MoreOptionsSheet> {
  bool _deleting = false;

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('reels.delete_confirm_title'.tr()),
        content: Text('reels.delete_confirm_body'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'reels.delete_confirm_action'.tr(),
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    final result = await getIt<ReelsRepository>().deleteReel(widget.reel.id);
    if (!mounted) return;
    result.fold(
      (_) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('reels.delete_failed'.tr())));
      },
      (_) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('reels.delete_success'.tr())));
      },
    );
  }

  void _report() {
    Navigator.of(context).pop();
    showReportReasonsSheet(context, widget.reel.id);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = getIt<ReelsInteractionCubit>();
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(AppConstants.spacingSm),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppConstants.spacingSm),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(AppConstants.radiusSm / 4),
              ),
            ),
            // v4 (FR-068): Save/Unsave relocated here from the action
            // column for every viewer (column slot now hosts Repost, US12).
            // Explicit colors below — this sheet forces a light surface
            // regardless of the app's global dark `ThemeData`, so default
            // (unstyled) text/icons would otherwise inherit dark-theme tints.
            BlocSelector<ReelsInteractionCubit, ReelsInteractionState, bool>(
              bloc: cubit,
              selector: (state) => state.saves[widget.reel.id] ?? false,
              builder: (context, saved) {
                final tint = saved ? AppColors.primary : AppColors.textSecondary;
                return ListTile(
                  leading: Icon(saved ? Icons.bookmark : Icons.bookmark_border, color: tint),
                  title: Text(
                    saved ? 'reels.saved'.tr() : 'reels.save'.tr(),
                    style: AppTypography.body1.copyWith(color: tint),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    cubit.toggleSave(widget.reel.id);
                  },
                );
              },
            ),
            if (widget.isOwner)
              ListTile(
                leading: _deleting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.error,
                        ),
                      )
                    : const Icon(Icons.delete_outline, color: AppColors.error),
                title: Text(
                  'reels.delete_menu'.tr(),
                  style: AppTypography.body1.copyWith(color: AppColors.error),
                ),
                onTap: _deleting ? null : _delete,
              )
            else
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: AppColors.error),
                title: Text(
                  'reels.report_menu'.tr(),
                  style: AppTypography.body1.copyWith(color: AppColors.error),
                ),
                onTap: _report,
              ),
            const SizedBox(height: AppConstants.spacingSm),
          ],
        ),
      ),
    );
  }
}
