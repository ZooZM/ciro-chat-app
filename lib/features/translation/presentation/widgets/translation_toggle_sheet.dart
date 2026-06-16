import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/supported_languages.dart';

/// Result of [TranslationToggleSheet] — `null` means the sheet was dismissed
/// without a decision (no change).
sealed class TranslationToggleResult {}

/// The listener wants translation enabled for [targetLanguage] (T025/US3).
class TranslationToggleOn extends TranslationToggleResult {
  final String targetLanguage;
  TranslationToggleOn(this.targetLanguage);
}

/// The listener wants translation disabled.
class TranslationToggleOff extends TranslationToggleResult {}

/// Modal bottom sheet with a CC on/off toggle and a target-language picker
/// (T025). [isEnabled]/[initialLanguage] seed the initial state from
/// `TranslationState.subscriptions[speakerId]` / `resolveTargetLanguage` (T026).
class TranslationToggleSheet extends StatefulWidget {
  final bool isEnabled;
  final String initialLanguage;

  const TranslationToggleSheet({
    super.key,
    required this.isEnabled,
    required this.initialLanguage,
  });

  @override
  State<TranslationToggleSheet> createState() => _TranslationToggleSheetState();
}

class _TranslationToggleSheetState extends State<TranslationToggleSheet> {
  late bool _enabled;
  late String _language;

  @override
  void initState() {
    super.initState();
    _enabled = widget.isEnabled;
    _language = widget.initialLanguage;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textHint,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'translation_toggle_title'.tr(),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('translation_toggle_enable'.tr()),
              value: _enabled,
              onChanged: (value) => setState(() => _enabled = value),
            ),
            if (_enabled) ...[
              const SizedBox(height: 8),
              Text(
                'translation_language_picker_title'.tr(),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: RadioGroup<String>(
                  groupValue: _language,
                  onChanged: (value) => setState(() => _language = value ?? _language),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final code in kSupportedTranslationLanguages)
                        RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          title: Text(kTranslationLanguageNames[code] ?? code),
                          value: code,
                        ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                final result = _enabled
                    ? TranslationToggleOn(_language)
                    : TranslationToggleOff();
                Navigator.of(context).pop(result);
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text('translation_apply'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
