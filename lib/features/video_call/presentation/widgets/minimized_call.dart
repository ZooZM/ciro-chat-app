import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/services/audio_route_service.dart';
import '../../../../core/services/call_audio_session_service.dart';
import '../bloc/call_cubit.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MinimizedCallController
//
// Presents the active call as a small draggable floating window over the whole
// app (like Snapchat / WhatsApp PiP) so the user can keep browsing while on a
// call. The LiveKit [Room] is handed over from the call screen (which sets
// `_isMinimizing` so its dispose does NOT disconnect), so the media session
// keeps running. Tapping the window restores the full call screen by re-pushing
// it with the same room via `externalRoom`.
//
// While minimized, THIS controller owns the room: it disconnects + tears down
// audio when the call ends. On restore it hands ownership back to the screen.
// ─────────────────────────────────────────────────────────────────────────────

class MinimizedCallController {
  MinimizedCallController._();
  static final MinimizedCallController instance = MinimizedCallController._();

  OverlayEntry? _entry;
  Room? _room;
  StreamSubscription<CallState>? _callSub;

  bool get isActive => _entry != null;

  void minimize({
    required Room room,
    required String contactName,
    required bool isVideo,
    required String livekitUrl,
    required String livekitToken,
    required DateTime startedAt,
    String? groupRoomId,
  }) {
    final overlay = globalNavigatorKey.currentState?.overlay;
    if (overlay == null) return;
    _entry?.remove();
    _room = room;
    _entry = OverlayEntry(
      builder: (_) => MinimizedCallWindow(
        room: room,
        contactName: contactName,
        isVideo: isVideo,
        onExpand: () => _restore(
            contactName, isVideo, livekitUrl, livekitToken, startedAt,
            groupRoomId: groupRoomId),
        onEnd: () => getIt<CallCubit>().endCall(),
      ),
    );
    overlay.insert(_entry!);

    // Own the room while minimized: tear it down when the call ends.
    _callSub?.cancel();
    _callSub = getIt<CallCubit>().stream.listen((s) {
      if (s is CallEnded || s is CallIdle) dismiss(disconnect: true);
    });
  }

  void _restore(
      String name, bool isVideo, String url, String token, DateTime startedAt,
      {String? groupRoomId}) {
    final room = _room;
    _callSub?.cancel();
    _callSub = null;
    _entry?.remove();
    _entry = null;
    _room = null; // ownership passes back to the restored screen
    if (room == null) return;
    final ctx = globalNavigatorKey.currentContext;
    if (ctx == null) return;
    // Group calls restore into the group screen; 1:1 (voice/video) into the
    // VideoCallScreen. Reusing the room preserves the live media state.
    if (groupRoomId != null && groupRoomId.isNotEmpty) {
      ctx.push('/group_call/$groupRoomId', extra: {
        'externalRoom': room,
        'callStartedAt': startedAt,
      });
      return;
    }
    ctx.push(
      AppRouterName.videoCall,
      extra: {
        'contactName': name,
        'livekitUrl': url,
        'livekitToken': token,
        'externalRoom': room,
        'callStartedAt': startedAt,
      },
    );
  }

  /// Removes the floating window. When [disconnect] is true (the call ended
  /// while minimized) the room + audio session are torn down here, since no
  /// screen is mounted to do it.
  Future<void> dismiss({required bool disconnect}) async {
    _callSub?.cancel();
    _callSub = null;
    _entry?.remove();
    _entry = null;
    final room = _room;
    _room = null;
    if (disconnect && room != null) {
      await room.disconnect();
      getIt<CallAudioSessionService>().deactivate();
      getIt<AudioRouteService>().stop();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MinimizedCallWindow — the draggable floating pill/PiP itself.
// ─────────────────────────────────────────────────────────────────────────────

class MinimizedCallWindow extends StatefulWidget {
  final Room room;
  final String contactName;
  final bool isVideo;
  final VoidCallback onExpand;
  final VoidCallback onEnd;

  const MinimizedCallWindow({
    super.key,
    required this.room,
    required this.contactName,
    required this.isVideo,
    required this.onExpand,
    required this.onEnd,
  });

  @override
  State<MinimizedCallWindow> createState() => _MinimizedCallWindowState();
}

class _MinimizedCallWindowState extends State<MinimizedCallWindow> {
  Offset _pos = const Offset(16, 100);
  EventsListener<RoomEvent>? _listener;

  static const double _w = 110;
  static const double _h = 150;

  @override
  void initState() {
    super.initState();
    // Rebuild when the remote video track comes/goes so the PiP shows it.
    _listener = widget.room.createListener();
    _listener!
      ..on<TrackSubscribedEvent>((_) {
        if (mounted) setState(() {});
      })
      ..on<TrackUnsubscribedEvent>((_) {
        if (mounted) setState(() {});
      })
      ..on<TrackMutedEvent>((_) {
        if (mounted) setState(() {});
      })
      ..on<TrackUnmutedEvent>((_) {
        if (mounted) setState(() {});
      });
  }

  @override
  void dispose() {
    _listener?.dispose();
    super.dispose();
  }

  VideoTrack? get _remoteVideo {
    for (final p in widget.room.remoteParticipants.values) {
      for (final pub in p.videoTrackPublications) {
        final t = pub.track;
        if (pub.subscribed && !pub.muted && t is VideoTrack) return t;
      }
    }
    return null;
  }

  // Insets that keep the window clear of the status bar/notch and bottom nav.
  static const double _topInset = 60;
  static const double _bottomInset = 100;
  static const double _sideInset = 16;

  /// Snaps the window to whichever screen corner it is nearest on release.
  void _snapToCorner(Size size) {
    final leftX = _sideInset;
    final rightX = size.width - _w - _sideInset;
    final topY = _topInset;
    final bottomY = size.height - _h - _bottomInset;
    final centerX = _pos.dx + _w / 2;
    final centerY = _pos.dy + _h / 2;
    setState(() {
      _pos = Offset(
        centerX < size.width / 2 ? leftX : rightX,
        centerY < size.height / 2 ? topY : bottomY,
      );
    });
  }

  String get _initials {
    final n = widget.contactName.trim();
    if (n.isEmpty) return '?';
    return n.length >= 2 ? n.substring(0, 2).toUpperCase() : n[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // Show remote video whenever it exists — even for a call that started as
    // voice, so an upgrade by the other side appears live in the window.
    final video = _remoteVideo;

    return Stack(
      children: [
        AnimatedPositioned(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          left: _pos.dx,
          top: _pos.dy,
          child: GestureDetector(
            onTap: widget.onExpand,
            onPanUpdate: (d) {
              setState(() {
                _pos = Offset(
                  (_pos.dx + d.delta.dx).clamp(0.0, size.width - _w),
                  (_pos.dy + d.delta.dy).clamp(40.0, size.height - _h - 40),
                );
              });
            },
            onPanEnd: (_) => _snapToCorner(size),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                width: _w,
                height: _h,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (video != null)
                      VideoTrackRenderer(video, fit: VideoViewFit.cover)
                    else
                      Container(
                        color: const Color(0xFFE33451),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: Colors.white24,
                              child: Text(
                                _initials,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Text(
                                widget.contactName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    // End-call button
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: GestureDetector(
                        onTap: widget.onEnd,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE53935),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.call_end,
                              color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
