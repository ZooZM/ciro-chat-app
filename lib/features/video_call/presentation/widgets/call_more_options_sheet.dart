import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CallMoreOptionsSheet
//
// The "≡ More" bottom sheet shown from a 1:1 call's control bar. Offers:
//   • Share Screen  (toggles to "Stop Sharing" while active)
//   • Translate     (opens the live-translation toggle for the other party)
//
// Pure UI — the caller wires the actual behavior via callbacks so both the
// voice and video call screens can reuse it.
// ─────────────────────────────────────────────────────────────────────────────

class CallMoreOptionsSheet extends StatelessWidget {
  final String title;
  final bool isSharing;
  final bool isTranslating;
  final VoidCallback onShareScreen;

  /// When null, the Translate row is hidden (e.g. the group screen exposes
  /// translation via the per-participant CC control instead).
  final VoidCallback? onTranslate;

  const CallMoreOptionsSheet({
    super.key,
    required this.title,
    required this.isSharing,
    required this.isTranslating,
    required this.onShareScreen,
    this.onTranslate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF2A2A3E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.view_column_outlined,
                      color: Colors.white70, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        color: Colors.white12,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close,
                          color: Colors.white70, size: 16),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _MoreOptionsTile(
              icon: Icons.ios_share,
              label: isSharing ? 'Stop Sharing' : 'Share Screen',
              onTap: onShareScreen,
            ),
            if (onTranslate != null)
              _MoreOptionsTile(
                icon: Icons.translate,
                label: isTranslating ? 'Translation' : 'Translate',
                onTap: onTranslate!,
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _MoreOptionsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MoreOptionsTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF3D3D55),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 22),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
