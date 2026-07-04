import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:ciro_chat_app/core/di/injection.dart';
import 'package:ciro_chat_app/core/theme/app_colors.dart';
import 'package:ciro_chat_app/core/theme/app_typography.dart';
import 'package:ciro_chat_app/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/reel.dart';
import 'package:ciro_chat_app/features/reels/domain/repositories/reels_repository.dart';

/// Three-dot "more options" entry in the interaction column (TikTok-style,
/// FR-067). Only rendered for the reel's owner — its only content today is
/// Delete, so it stays hidden for every other viewer rather than opening an
/// empty sheet.
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
      builder: (_) => _MoreOptionsSheet(reel: widget.reel),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isOwner) return const SizedBox.shrink();
    return GestureDetector(
      onTap: _openSheet,
      child: const Icon(
        CupertinoIcons.ellipsis,
        color: Colors.white,
        size: 30,
        shadows: [Shadow(color: Colors.white, blurRadius: 8)],
      ),
    );
  }
}

class _MoreOptionsSheet extends StatefulWidget {
  const _MoreOptionsSheet({required this.reel});

  final Reel reel;

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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
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
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
