import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:ciro_chat_app/core/di/injection.dart';
import 'package:ciro_chat_app/core/error/failures.dart';
import 'package:ciro_chat_app/core/theme/app_colors.dart';
import 'package:ciro_chat_app/core/theme/app_constants.dart';
import 'package:ciro_chat_app/core/theme/app_typography.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/report_reason.dart';
import 'package:ciro_chat_app/features/reels/domain/repositories/reels_repository.dart';

/// v4 (FR-068/FR-069): preset reasons + "Other" (reveals a required custom
/// text field). Opened from the 3-dots more-options sheet's Report entry.
Future<void> showReportReasonsSheet(BuildContext context, String reelId) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _ReportReasonsSheet(reelId: reelId),
  );
}

class _ReportReasonsSheet extends StatefulWidget {
  const _ReportReasonsSheet({required this.reelId});

  final String reelId;

  @override
  State<_ReportReasonsSheet> createState() => _ReportReasonsSheetState();
}

class _ReportReasonsSheetState extends State<_ReportReasonsSheet> {
  ReportReason? _reason;
  final _customController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    if (_reason == null || _submitting) return false;
    if (_reason == ReportReason.other) {
      return _customController.text.trim().isNotEmpty;
    }
    return true;
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final reason = _reason!;
    setState(() => _submitting = true);
    final result = await getIt<ReelsRepository>().reportReel(
      widget.reelId,
      reason,
      customReason: reason == ReportReason.other ? _customController.text.trim() : null,
    );
    if (!mounted) return;
    result.fold(
      (failure) {
        setState(() => _submitting = false);
        final key = failure is RateLimitedFailure
            ? 'reels.report_rate_limited'
            : 'reels.report_failed';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(key.tr())));
      },
      (alreadyReported) {
        Navigator.of(context).pop();
        final key = alreadyReported ? 'reels.report_already' : 'reels.report_success';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(key.tr())));
      },
    );
  }

  String _labelFor(ReportReason reason) {
    switch (reason) {
      case ReportReason.spam:
        return 'reels.report_reason_spam';
      case ReportReason.nudity:
        return 'reels.report_reason_nudity';
      case ReportReason.violence:
        return 'reels.report_reason_violence';
      case ReportReason.hateSpeech:
        return 'reels.report_reason_hate_speech';
      case ReportReason.other:
        return 'reels.report_reason_other';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOther = _reason == ReportReason.other;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('reels.report_title'.tr(), style: AppTypography.body1),
                ),
              ),
              RadioGroup<ReportReason>(
                groupValue: _reason,
                onChanged: (value) {
                  if (_submitting) return;
                  setState(() => _reason = value);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final reason in ReportReason.values)
                      RadioListTile<ReportReason>(
                        value: reason,
                        activeColor: AppColors.primary,
                        title: Text(_labelFor(reason).tr(), style: AppTypography.body2),
                      ),
                  ],
                ),
              ),
              if (isOther)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppConstants.spacingMd,
                    0,
                    AppConstants.spacingMd,
                    AppConstants.spacingSm,
                  ),
                  child: TextField(
                    controller: _customController,
                    maxLength: 500,
                    maxLines: 3,
                    enabled: !_submitting,
                    onChanged: (_) => setState(() {}),
                    style: AppTypography.body1,
                    decoration: AppConstants.inputDecoration(
                      hint: 'reels.report_custom_hint'.tr(),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppConstants.spacingMd,
                  0,
                  AppConstants.spacingMd,
                  AppConstants.spacingMd,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _canSubmit ? _submit : null,
                    style: AppConstants.primaryButtonStyle,
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text('reels.report_submit'.tr(), style: AppTypography.buttonText),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
