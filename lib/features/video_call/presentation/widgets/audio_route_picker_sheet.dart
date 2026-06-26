import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/services/audio_route_service.dart';

/// In-call bottom sheet that lists every available audio output route and lets
/// the user pick one (FR-VoIP-07). Lives in the `video_call` feature because it
/// is an in-call widget (Constitution §I).
class AudioRoutePickerSheet extends StatelessWidget {
  const AudioRoutePickerSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => const AudioRoutePickerSheet(),
      );

  @override
  Widget build(BuildContext context) {
    final service = getIt<AudioRouteService>();
    return StreamBuilder<AudioRouteState>(
      stream: service.routeStream,
      initialData: service.current,
      builder: (context, snapshot) {
        final state = snapshot.data ?? const AudioRouteState();
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Audio output', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              for (final device in state.availableRoutes)
                ListTile(
                  leading: Icon(_iconFor(device.route)),
                  title: Text(device.label),
                  trailing: device.route == state.activeRoute
                      ? const Icon(Icons.check, color: Colors.green)
                      : null,
                  onTap: () async {
                    await service.selectRoute(device.route, deviceId: device.id);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  static IconData _iconFor(AudioOutputRoute route) => switch (route) {
        AudioOutputRoute.earpiece => Icons.phone_in_talk,
        AudioOutputRoute.speaker => Icons.volume_up,
        AudioOutputRoute.bluetooth => Icons.bluetooth_audio,
      };
}

/// The speaker icon to show on the active-call control bar, reflecting the
/// current route (FR-VoIP-08).
IconData speakerIconForRoute(AudioOutputRoute route) => switch (route) {
      AudioOutputRoute.earpiece => Icons.volume_up_outlined,
      AudioOutputRoute.speaker => Icons.volume_up,
      AudioOutputRoute.bluetooth => Icons.bluetooth_audio,
    };
