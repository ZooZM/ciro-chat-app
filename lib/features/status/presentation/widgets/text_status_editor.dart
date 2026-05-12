import 'package:ciro_chat_app/core/theme/app_constants.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class TextStatusEditor extends StatefulWidget {
  final String textContent;
  final ValueChanged<String> onChanged;
  final String fontStyle; // Could map to specific GoogleFonts later

  const TextStatusEditor({
    super.key,
    required this.textContent,
    required this.onChanged,
    required this.fontStyle,
  });

  @override
  State<TextStatusEditor> createState() => _TextStatusEditorState();
}

class _TextStatusEditorState extends State<TextStatusEditor> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.textContent);
  }

  @override
  void didUpdateWidget(covariant TextStatusEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.textContent != widget.textContent && _controller.text != widget.textContent) {
      _controller.text = widget.textContent;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine font family based on fontStyle string (for MVP just return default or specific style)
    TextStyle textStyle = TextStyle(
      fontSize: 36,
      color: Colors.white,
      fontWeight: FontWeight.bold,
      fontFamily: widget.fontStyle.isNotEmpty ? widget.fontStyle : null,
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingLg),
        child: TextField(
          controller: _controller,
          onChanged: widget.onChanged,
          textAlign: TextAlign.center,
          maxLines: null,
          style: textStyle,
          cursorColor: Colors.white,
          decoration: InputDecoration(
            hintText: 'status.write_status'.tr(),
            hintStyle: textStyle.copyWith(color: Colors.white54),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ),
      ),
    );
  }
}
