import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ciro_chat_app/core/theme/app_colors.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/followed_user.dart';
import 'package:ciro_chat_app/features/reels/presentation/bloc/mention_suggestions_cubit.dart';

/// The active `@`-fragment right before the cursor (unicode-aware so accented
/// names filter correctly), e.g. text `"hi @sa"` with the cursor at the end
/// matches `"sa"`. Not anchored to the string end when composed inline —
/// callers must pass only the text *before* the cursor.
final RegExp _mentionTokenPattern = RegExp(r'@([\p{L}\p{N}_]{0,30})$', unicode: true);

/// v5 (FR-083): wraps the description [child] (a `TextField`) with a live
/// `@`-mention suggestion panel anchored above it via [OverlayPortal] +
/// [CompositedTransformFollower] — no third-party autocomplete package
/// (R23). Must be a descendant of a `BlocProvider<MentionSuggestionsCubit>`.
class MentionSuggestionsOverlay extends StatefulWidget {
  const MentionSuggestionsOverlay({
    super.key,
    required this.controller,
    required this.child,
  });

  final TextEditingController controller;
  final Widget child;

  @override
  State<MentionSuggestionsOverlay> createState() => _MentionSuggestionsOverlayState();
}

class _MentionSuggestionsOverlayState extends State<MentionSuggestionsOverlay> {
  final _overlayController = OverlayPortalController();
  final _link = LayerLink();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTextChanged);
    super.dispose();
  }

  void _handleTextChanged() {
    final cubit = context.read<MentionSuggestionsCubit>();
    final selection = widget.controller.selection;
    if (!selection.isValid || !selection.isCollapsed) {
      cubit.updateToken(null);
      return;
    }
    final beforeCursor = widget.controller.text.substring(0, selection.start);
    final match = _mentionTokenPattern.firstMatch(beforeCursor);
    cubit.updateToken(match?.group(1));
  }

  void _selectUser(FollowedUser user) {
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    if (!selection.isValid) return;
    final beforeCursor = text.substring(0, selection.start);
    final match = _mentionTokenPattern.firstMatch(beforeCursor);
    if (match == null) return;

    final replacement = '@${user.username} ';
    final newText = text.replaceRange(match.start, selection.start, replacement);
    final newCursorOffset = match.start + replacement.length;
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorOffset),
    );
    context.read<MentionSuggestionsCubit>().dismiss();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<MentionSuggestionsCubit, MentionSuggestionsState>(
      listenWhen: (prev, curr) => curr.visibility != prev.visibility,
      listener: (context, state) {
        if (state.visibility == MentionSuggestionsVisibility.active) {
          _overlayController.show();
        } else {
          _overlayController.hide();
        }
      },
      child: CompositedTransformTarget(
        link: _link,
        child: OverlayPortal(
          controller: _overlayController,
          overlayChildBuilder: (context) {
            // The description field sits near the top of the post-details
            // screen (FR-082), so the panel is anchored *below* it rather
            // than above — the field's own text stays fully visible either
            // way, and this keeps the panel on-screen for a top-of-screen
            // field instead of being pushed above the viewport.
            return CompositedTransformFollower(
              link: _link,
              targetAnchor: Alignment.bottomLeft,
              followerAnchor: Alignment.topLeft,
              offset: const Offset(0, 8),
              child: Align(
                alignment: AlignmentDirectional.topStart,
                child: _SuggestionsPanel(onSelected: _selectUser),
              ),
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}

class _SuggestionsPanel extends StatelessWidget {
  const _SuggestionsPanel({required this.onSelected});

  final ValueChanged<FollowedUser> onSelected;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MentionSuggestionsCubit, MentionSuggestionsState>(
      buildWhen: (prev, curr) =>
          curr.visibility == MentionSuggestionsVisibility.active &&
          (curr.matches != prev.matches || curr.query != prev.query),
      builder: (context, state) {
        if (state.visibility != MentionSuggestionsVisibility.active ||
            state.matches.isEmpty) {
          return const SizedBox.shrink();
        }
        return Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220, maxWidth: 280),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: state.matches.length,
              itemBuilder: (context, index) {
                final user = state.matches[index];
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    backgroundColor: AppColors.surfaceVariant,
                    backgroundImage: (user.avatarUrl ?? '').isEmpty
                        ? null
                        : CachedNetworkImageProvider(user.avatarUrl!),
                    child: (user.avatarUrl ?? '').isEmpty
                        ? const Icon(Icons.person, color: AppColors.textSecondary)
                        : null,
                  ),
                  title: Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('@${user.username}', maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => onSelected(user),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
