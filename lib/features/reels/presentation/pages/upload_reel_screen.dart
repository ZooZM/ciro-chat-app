import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ciro_chat_app/core/di/injection.dart';
import 'package:ciro_chat_app/features/reels/presentation/bloc/mention_suggestions_cubit.dart';
import 'package:ciro_chat_app/features/reels/presentation/bloc/upload_cubit.dart';
import 'package:ciro_chat_app/features/reels/presentation/widgets/mention_suggestions_overlay.dart';

/// v5 (FR-082): the post-details step — a minimal screen containing only
/// the description input (with the FR-083 `@`-mention overlay), a preview
/// thumbnail of the trimmed segment, and a prominent Post button. Reached
/// exclusively from the trimmer ([ReelCaptureScreen]'s "Next" step); source
/// selection now lives entirely in the camera-first capture flow.
class UploadReelScreen extends StatelessWidget {
  const UploadReelScreen({
    super.key,
    required this.videoPath,
    this.thumbnailPath,
  });

  final String videoPath;
  final String? thumbnailPath;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getIt<UploadCubit>()),
        BlocProvider(create: (_) => getIt<MentionSuggestionsCubit>()..ensureLoaded()),
      ],
      child: _PostDetailsView(videoPath: videoPath, thumbnailPath: thumbnailPath),
    );
  }
}

class _PostDetailsView extends StatefulWidget {
  const _PostDetailsView({required this.videoPath, this.thumbnailPath});

  final String videoPath;
  final String? thumbnailPath;

  @override
  State<_PostDetailsView> createState() => _PostDetailsViewState();
}

class _PostDetailsViewState extends State<_PostDetailsView> {
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    context.read<UploadCubit>().upload(
          videoPath: widget.videoPath,
          thumbnailPath: widget.thumbnailPath,
          description: _descriptionController.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('reels.upload_title'.tr())),
      body: BlocConsumer<UploadCubit, UploadState>(
        listener: (context, state) {
          if (state.status == UploadStatus.success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('reels.upload_success'.tr())),
            );
            Navigator.of(context).pop(state.uploadedReel);
          }
        },
        builder: (context, state) {
          if (state.status == UploadStatus.uploading) {
            return _UploadProgressView(progress: state.progress);
          }
          if (state.status == UploadStatus.failure) {
            return _UploadFailureView(message: state.errorMessage, onRetry: _submit);
          }
          return _PostDetailsForm(
            thumbnailPath: widget.thumbnailPath,
            descriptionController: _descriptionController,
            onSubmit: _submit,
          );
        },
      ),
    );
  }
}

class _PostDetailsForm extends StatelessWidget {
  const _PostDetailsForm({
    required this.thumbnailPath,
    required this.descriptionController,
    required this.onSubmit,
  });

  final String? thumbnailPath;
  final TextEditingController descriptionController;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: MentionSuggestionsOverlay(
                      controller: descriptionController,
                      child: TextField(
                        controller: descriptionController,
                        maxLength: 2200,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: InputDecoration(
                          hintText: 'reels.post_description_hint'.tr(),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 100,
                    child: AspectRatio(
                      aspectRatio: 9 / 16,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: thumbnailPath == null
                            ? Container(color: Colors.black12)
                            : Image.file(File(thumbnailPath!), fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onSubmit,
              child: Text('reels.post_submit'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadProgressView extends StatelessWidget {
  const _UploadProgressView({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(value: progress > 0 ? progress : null),
          const SizedBox(height: 16),
          Text('reels.upload_progress'.tr()),
        ],
      ),
    );
  }
}

class _UploadFailureView extends StatelessWidget {
  const _UploadFailureView({required this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 40),
          const SizedBox(height: 12),
          Text(message ?? 'reels.upload_failed_retry'.tr()),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onRetry,
            child: Text('reels.upload_failed_retry'.tr()),
          ),
        ],
      ),
    );
  }
}
