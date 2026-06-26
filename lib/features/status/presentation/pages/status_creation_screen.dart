import 'dart:io';

import 'package:ciro_chat_app/core/di/injection.dart';
import 'package:ciro_chat_app/core/theme/app_colors.dart';
import 'package:ciro_chat_app/core/theme/app_constants.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_content_type.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_entity.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_privacy.dart';
import 'package:ciro_chat_app/features/status/presentation/bloc/status_creation_cubit.dart';
import 'package:ciro_chat_app/features/status/presentation/bloc/status_creation_state.dart';
import 'package:ciro_chat_app/features/status/presentation/bloc/status_cubit.dart';
import 'package:ciro_chat_app/features/status/presentation/widgets/color_palette_picker.dart';
import 'package:ciro_chat_app/features/status/presentation/widgets/mode_switcher_bar.dart';
import 'package:ciro_chat_app/features/status/presentation/widgets/status_toolbar.dart';
import 'package:ciro_chat_app/features/status/presentation/widgets/text_status_editor.dart';
import 'package:ciro_chat_app/features/status/presentation/widgets/voice_status_editor.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class StatusCreationScreen extends StatefulWidget {
  final StatusContentType initialMode;
  final String? initialMediaPath;

  const StatusCreationScreen({
    super.key,
    required this.initialMode,
    this.initialMediaPath,
  });

  @override
  State<StatusCreationScreen> createState() => _StatusCreationScreenState();
}

class _StatusCreationScreenState extends State<StatusCreationScreen> {
  late final StatusCreationCubit _cubit;
  bool _showColorPalette = false;

  final List<String> _fontFamilies = [
    '', // Default
    'Roboto',
    'Courier',
    'Serif',
  ];
  int _currentFontIndex = 0;

  @override
  void initState() {
    super.initState();
    _cubit = getIt<StatusCreationCubit>();
    _cubit.initDraft(widget.initialMode);
    if (widget.initialMediaPath != null) {
      _cubit.attachMedia(widget.initialMediaPath!, widget.initialMode);
    }
  }

  void _cycleFont() {
    _currentFontIndex = (_currentFontIndex + 1) % _fontFamilies.length;
    _cubit.updateFontStyle(_fontFamilies[_currentFontIndex]);
  }

  Color _parseColor(String hexCode) {
    hexCode = hexCode.replaceAll('#', '');
    if (hexCode.length == 6) {
      hexCode = 'FF$hexCode'; // add alpha if missing
    }
    return Color(int.parse(hexCode, radix: 16));
  }

  String _toHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocConsumer<StatusCreationCubit, StatusCreationState>(
        listener: (context, state) {
          if (state is StatusCreationSuccess) {
            // The composer's own cubit is a separate instance from the
            // app-root StatusCubit the Updates screen reads — without this,
            // "My Status" keeps showing stale data until something else
            // happens to trigger a reload.
            context.read<StatusCubit>().loadRecentStatuses();
            context.pop();
          } else if (state is StatusCreationError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        builder: (context, state) {
          if (state is StatusCreationIdle || state is StatusCreationSuccess) {
            return const Scaffold(backgroundColor: Colors.black);
          }

          StatusEntity draft;
          bool isUploading = false;
          if (state is StatusCreationComposing) {
            draft = state.draft;
          } else if (state is StatusCreationUploading) {
            draft = state.draft;
            isUploading = true;
          } else if (state is StatusCreationError) {
            draft = state.draft;
          } else {
            return const SizedBox.shrink();
          }

          final bgColor = draft.backgroundColor != null
              ? _parseColor(draft.backgroundColor!)
              : Colors.black;

          return Scaffold(
            backgroundColor: bgColor,
            resizeToAvoidBottomInset: false,
            body: SafeArea(
              child: Stack(
                children: [
                  // Editor Content
                  Positioned.fill(
                    child: _buildEditor(draft),
                  ),

                  // Top Toolbar
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: StatusToolbar(
                      activeMode: draft.contentType,
                      isColorPaletteOpen: _showColorPalette,
                      onClose: () {
                        if (_showColorPalette) {
                          setState(() {
                            _showColorPalette = false;
                          });
                        } else {
                          _cubit.reset();
                          context.pop();
                        }
                      },
                      onPaletteTap: () {
                        setState(() {
                          _showColorPalette = !_showColorPalette;
                        });
                      },
                      onFontTap: _cycleFont,
                      currentPrivacy: draft.privacy,
                      onPrivacyChanged: _cubit.updatePrivacy,
                      onSelectContacts: () {
                        // TODO: Implement contact selection
                      },
                    ),
                  ),

                  // Music Indicator
                  if (draft.musicTrackId != null)
                    Positioned(
                      top: 100,
                      left: AppConstants.spacingMd,
                      right: AppConstants.spacingMd,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingMd, vertical: AppConstants.spacingSm),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(AppConstants.radiusPill),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.music_note, color: Colors.white, size: 16),
                              const SizedBox(width: AppConstants.spacingSm),
                              Text('status.music_attached'.tr(), style: const TextStyle(color: Colors.white)),
                              const SizedBox(width: AppConstants.spacingSm),
                              GestureDetector(
                                onTap: () => _cubit.attachMusicTrack(''), // clear music
                                child: const Icon(Icons.close, color: Colors.white70, size: 16),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Bottom Controls
                  Positioned(
                    bottom: AppConstants.spacingMd,
                    left: 0,
                    right: 0,
                    child: _showColorPalette
                        ? Padding(
                            padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingMd),
                            child: ColorPalettePicker(
                              selectedColor: bgColor,
                              onColorSelected: (c) {
                                _cubit.updateBackgroundColor(_toHex(c));
                                setState(() => _showColorPalette = false);
                              },
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    left: AppConstants.spacingMd,
                                    right: AppConstants.spacingSm,
                                  ),
                                  child: ModeSwitcherBar(
                                    activeMode: draft.contentType,
                                    onModeChanged: (mode) {
                                      _cubit.switchMode(mode);
                                      setState(() => _showColorPalette = false);
                                    },
                                  ),
                                ),
                              ),
                              if (draft.contentType != StatusContentType.voice)
                                Padding(
                                  padding: const EdgeInsets.only(right: AppConstants.spacingMd),
                                  child: FloatingActionButton(
                                    backgroundColor: AppColors.primary,
                                    onPressed: isUploading ? null : _cubit.submitStatus,
                                    child: isUploading
                                        ? const CircularProgressIndicator(color: Colors.white)
                                        : const Icon(Icons.send, color: Colors.white),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEditor(StatusEntity draft) {
    switch (draft.contentType) {
      case StatusContentType.text:
        return TextStatusEditor(
          textContent: draft.textContent ?? '',
          onChanged: _cubit.updateText,
          fontStyle: draft.fontStyle ?? '',
        );
      case StatusContentType.image:
        return draft.mediaUrl != null
            ? Center(child: Image.file(File(draft.mediaUrl!), fit: BoxFit.contain))
            : Center(child: Text('status.image'.tr(), style: const TextStyle(color: Colors.white)));
      case StatusContentType.video:
        return Center(child: Text('status.image'.tr(), style: const TextStyle(color: Colors.white))); // Placeholder for media
      case StatusContentType.voice:
        return const VoiceStatusEditor();
    }
  }
}
