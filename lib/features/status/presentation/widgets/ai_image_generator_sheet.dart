import 'package:ciro_chat_app/core/theme/app_colors.dart';
import 'package:ciro_chat_app/core/theme/app_constants.dart';
import 'package:ciro_chat_app/features/status/domain/entities/ai_image_result.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class AIImageGeneratorSheet extends StatefulWidget {
  final Future<AIImageResult> Function(String prompt) onGenerate;
  final ValueChanged<String> onImageSelected;
  final VoidCallback onVoicePromptTapped; // For voice-to-text integration

  const AIImageGeneratorSheet({
    super.key,
    required this.onGenerate,
    required this.onImageSelected,
    required this.onVoicePromptTapped,
  });

  @override
  State<AIImageGeneratorSheet> createState() => _AIImageGeneratorSheetState();
}

class _AIImageGeneratorSheetState extends State<AIImageGeneratorSheet> {
  final TextEditingController _promptController = TextEditingController();
  bool _isGenerating = false;
  AIImageResult? _result;
  String? _error;

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  void _generateImage() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return;

    setState(() {
      _isGenerating = true;
      _error = null;
      _result = null;
    });

    try {
      final result = await widget.onGenerate(prompt).timeout(const Duration(seconds: 15));
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _result = result;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _error = 'Failed to generate image. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: AppConstants.sheetRadius,
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: AppConstants.spacingSm, bottom: AppConstants.spacingMd),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(AppConstants.radiusPill),
            ),
          ),
          
          Text(
            'status.create_any_image'.tr(),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          
          const SizedBox(height: AppConstants.spacingMd),

          Expanded(
            child: _isGenerating
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: AppConstants.spacingMd),
                        Text('Generating your masterpiece...'),
                      ],
                    ),
                  )
                : _result != null
                    ? Column(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(AppConstants.spacingMd),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                                child: Image.network(_result!.imageUrl, fit: BoxFit.cover),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(AppConstants.spacingMd),
                            child: Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => setState(() => _result = null),
                                    child: const Text('Try Again'),
                                  ),
                                ),
                                const SizedBox(width: AppConstants.spacingMd),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => widget.onImageSelected(_result!.imageUrl),
                                    child: const Text('Use Image'),
                                  ),
                                ),
                              ],
                            ),
                          )
                        ],
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(AppConstants.spacingMd),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: AppConstants.spacingSm,
                          mainAxisSpacing: AppConstants.spacingSm,
                        ),
                        itemCount: 4, // 4 placeholders/inspirations
                        itemBuilder: (context, index) {
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                            ),
                            child: const Center(child: Icon(Icons.image, color: Colors.grey, size: 48)),
                          );
                        },
                      ),
          ),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),

          if (!_isGenerating && _result == null)
            Padding(
              padding: EdgeInsets.only(
                left: AppConstants.spacingMd,
                right: AppConstants.spacingMd,
                bottom: MediaQuery.of(context).viewInsets.bottom + AppConstants.spacingMd,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _promptController,
                      decoration: InputDecoration(
                        hintText: 'status.create_image_for'.tr(),
                        filled: true,
                        fillColor: Colors.grey.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppConstants.radiusPill),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                      onSubmitted: (_) => _generateImage(),
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingSm),
                  IconButton(
                    icon: const Icon(Icons.mic, color: AppColors.primary),
                    onPressed: widget.onVoicePromptTapped,
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: AppColors.primary),
                    onPressed: _generateImage,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
