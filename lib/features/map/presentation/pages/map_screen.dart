import 'package:ciro_chat_app/features/map/presentation/bloc/map_cubit.dart';
import 'package:ciro_chat_app/features/map/presentation/bloc/map_state.dart';
import 'package:ciro_chat_app/features/map/presentation/mock/map_mock_data.dart';
import 'package:ciro_chat_app/features/map/presentation/widgets/map_avatar_marker.dart';
import 'package:ciro_chat_app/features/map/presentation/widgets/map_fab_column.dart';
import 'package:ciro_chat_app/features/map/presentation/widgets/map_filter_sheet.dart';
import 'package:ciro_chat_app/features/map/presentation/widgets/map_top_bar.dart';
import 'package:ciro_chat_app/features/map/presentation/widgets/user_details_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ciro_chat_app/core/theme/app_colors.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MapCubit, MapState>(
      builder: (context, state) {
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
                  myLocationEnabled: false,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  markers: state.googleMarkers,
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
                      ),
                    ),
                  ),
                ),
                // ── Right FAB column ──────────────────────────────────────────
                Positioned(
                  right: 12,
                  bottom: 20,
                  child: MapFabColumn(
                    onFilterTap: () => _showFilterSheet(context),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showUserDetails(BuildContext context, MockUser user) {
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
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 20),
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
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: child,
        );
      },
    );
  }
}
