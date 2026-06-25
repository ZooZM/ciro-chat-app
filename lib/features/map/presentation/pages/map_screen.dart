import 'dart:async';
import 'dart:ui' as ui;

import 'package:ciro_chat_app/core/routing/app_router.dart';
import 'package:ciro_chat_app/features/map/domain/entities/map_user.dart';
import 'package:ciro_chat_app/features/map/presentation/bloc/map_cubit.dart';
import 'package:ciro_chat_app/features/map/presentation/bloc/map_state.dart';
import 'package:ciro_chat_app/features/map/presentation/widgets/map_fab_column.dart';
import 'package:ciro_chat_app/features/map/presentation/widgets/map_filter_sheet.dart';
import 'package:ciro_chat_app/features/map/presentation/widgets/map_top_bar.dart';
import 'package:ciro_chat_app/features/map/presentation/widgets/user_details_sheet.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_cluster_manager_2/google_maps_cluster_manager_2.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'
    hide ClusterManager, Cluster;

/// Wraps an already-resolved per-user [Marker] (icon included) so the
/// cluster manager (FR-029/SC-011) can group nearby markers purely by
/// position, without re-deriving anything the cubit already computed.
class _MarkerClusterItem with ClusterItem {
  _MarkerClusterItem(this.marker);

  final Marker marker;

  @override
  LatLng get location => marker.position;
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late final ClusterManager<_MarkerClusterItem> _clusterManager;
  Set<Marker> _renderedMarkers = {};
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _clusterManager = ClusterManager<_MarkerClusterItem>(
      const <_MarkerClusterItem>[],
      (markers) {
        if (mounted) setState(() => _renderedMarkers = markers);
      },
      markerBuilder: _buildClusterMarker,
    );
  }

  /// Centers the camera on the device's current position. [force] re-fetches
  /// even if a location is already known (explicit Locate Me tap); otherwise
  /// this only does anything the first time a location becomes available
  /// (e.g. right after the map is created), making "current location" the
  /// effective initial view without needing a second, real device fix before
  /// `GoogleMap.initialCameraPosition` is evaluated.
  Future<void> _goToCurrentLocation({bool force = false}) async {
    final cubit = context.read<MapCubit>();
    await cubit.locateMe(force: force);
    final location = cubit.state.selfLocation;
    if (location != null) {
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(location, 16),
      );
    }
  }

  Future<Marker> _buildClusterMarker(
    Cluster<_MarkerClusterItem> cluster,
  ) async {
    if (!cluster.isMultiple) return cluster.items.first.marker;
    return Marker(
      markerId: MarkerId('cluster_${cluster.getId()}'),
      position: cluster.location,
      icon: await _clusterBadge(cluster.count),
      onTap:
          () {}, // Clusters split apart on zoom; no detail sheet for a group.
    );
  }

  Future<BitmapDescriptor> _clusterBadge(int count) async {
    const size = 96.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..color = const Color(0xFF1E3A5F);
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2, paint);
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2 - 3,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    final painter = TextPainter(textDirection: ui.TextDirection.ltr)
      ..text = TextSpan(
        text: '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 30,
          fontWeight: FontWeight.bold,
        ),
      )
      ..layout();
    painter.paint(
      canvas,
      Offset((size - painter.width) / 2, (size - painter.height) / 2),
    );
    final image = await recorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MapCubit, MapState>(
      builder: (context, state) {
        _clusterManager.setItems(
          state.googleMarkers.map(_MarkerClusterItem.new).toList(),
        );
        final cubit = context.read<MapCubit>();
        return BlocListener<MapCubit, MapState>(
          listenWhen: (previous, current) =>
              previous.selectedUser != current.selectedUser &&
              current.selectedUser != null,
          listener: (context, state) {
            _showUserDetails(context, state.selectedUser!);
          },
          child: Scaffold(
            extendBodyBehindAppBar: true,
            backgroundColor: const Color(0xFFECECEC),
            body: Stack(
              children: [
                // ── Full-screen Google Map ───────────────────────────────────────
                GoogleMap(
                  initialCameraPosition: const CameraPosition(
                    target: LatLng(30.0570, 31.2195),
                    zoom: 13.5,
                  ),
                  mapType: state.mapType,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  markers: _renderedMarkers,
                  onMapCreated: (controller) {
                    _mapController = controller;
                    _clusterManager.setMapId(controller.mapId);
                    unawaited(_goToCurrentLocation());
                  },
                  onCameraMove: _clusterManager.onCameraMove,
                  onCameraIdle: _clusterManager.updateMap,
                ),
                // ── Top bar overlay ───────────────────────────────────────────
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: MapTopBar(
                        selectedTab: state.selectedTab,
                        onTabChanged: cubit.switchTab,
                        onInvite: () =>
                            context.push(AppRouterName.inviteToShareLocation),
                        onCreateGroup: () async {
                          await context.push(AppRouterName.createGroup);
                          // The create-group flow can also be cancelled
                          // (back button) without creating anything — this
                          // refresh is a no-op then, and picks up a newly
                          // created group's filter entry otherwise.
                          if (context.mounted) cubit.loadGroups();
                        },
                      ),
                    ),
                  ),
                ),
                // ── Loading / empty / error overlays ──────────────────────────
                if (state.status == MapViewStatus.loading)
                  const Center(child: CircularProgressIndicator()),
                // if (state.status == MapViewStatus.empty)
                //   Center(
                //     child: _MapMessage(
                //       text: state.selectedTab == MapTab.explore
                //           ? 'map_empty_explore'.tr()
                //           : 'map_empty_following'.tr(),
                //     ),
                //   ),
                if (state.status == MapViewStatus.error)
                  Center(
                    child: _MapMessage(
                      text: 'map_error_loading'.tr(),
                      actionLabel: 'map_retry'.tr(),
                      onAction: cubit.retry,
                    ),
                  ),
                // ── Right FAB column ──────────────────────────────────────────
                Positioned(
                  right: 12,
                  bottom: 20,
                  child: MapFabColumn(
                    onFilterTap: () => _showFilterSheet(context),
                    onLocateMe: () =>
                        unawaited(_goToCurrentLocation(force: true)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showUserDetails(BuildContext context, MapUser user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => UserDetailsSheet(user: user),
    ).whenComplete(() {
      if (context.mounted) {
        context.read<MapCubit>().selectUser(null);
      }
    });
  }

  void _showFilterSheet(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 20,
            ),
            child: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.85,
                child: const MapFilterSheet(),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: child,
        );
      },
    );
  }
}

class _MapMessage extends StatelessWidget {
  const _MapMessage({required this.text, this.actionLabel, this.onAction});

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, textAlign: TextAlign.center),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
