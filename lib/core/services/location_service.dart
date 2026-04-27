import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';

/// Result of a location request — either success with data or failure with reason.
class LocationResult {
  final double? latitude;
  final double? longitude;
  final String? address;
  final String? errorMessage;

  bool get isSuccess => latitude != null && longitude != null;

  const LocationResult._({
    this.latitude,
    this.longitude,
    this.address,
    this.errorMessage,
  });

  factory LocationResult.success({
    required double latitude,
    required double longitude,
    required String address,
  }) =>
      LocationResult._(
        latitude: latitude,
        longitude: longitude,
        address: address,
      );

  factory LocationResult.failure(String message) =>
      LocationResult._(errorMessage: message);
}

/// Centralized location service that handles permission, GPS availability,
/// position fetching, and reverse geocoding.
///
/// Usage:
/// ```dart
/// final result = await LocationService.getCurrentLocation(context);
/// if (result.isSuccess) {
///   // use result.latitude, result.longitude, result.address
/// }
/// ```
class LocationService {
  LocationService._();

  /// Requests location permission, checks GPS, fetches position, and
  /// reverse-geocodes the result. Shows dialogs for permission/GPS issues.
  ///
  /// Returns [LocationResult.success] with lat/lng/address, or
  /// [LocationResult.failure] with a human-readable error message.
  static Future<LocationResult> getCurrentLocation(BuildContext context) async {
    // ── 1. Request permission ──────────────────────────────────────────
    final permStatus = await Permission.location.request();
    if (!permStatus.isGranted) {
      if (permStatus.isPermanentlyDenied && context.mounted) {
        final openSettings = await _showDialog(
          context,
          title: 'Location Permission Required',
          message:
              'Location permission is permanently denied. Please enable it in app settings.',
          confirmLabel: 'Open Settings',
        );
        if (openSettings == true) {
          await openAppSettings();
        }
      }
      return LocationResult.failure('Location permission denied');
    }

    // ── 2. Check if GPS / location services are enabled ────────────────
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!context.mounted) {
        return LocationResult.failure('Location services disabled');
      }
      final openSettings = await _showDialog(
        context,
        title: 'Location Services Disabled',
        message:
            'GPS is turned off. Please enable location services to share your location.',
        confirmLabel: 'Open Settings',
      );
      if (openSettings == true) {
        await Geolocator.openLocationSettings();
      }
      return LocationResult.failure('Location services disabled');
    }

    // ── 3. Fetch current position ──────────────────────────────────────
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      // ── 4. Reverse geocode ───────────────────────────────────────────
      String address = 'Unknown Location';
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final parts = <String>[
            if (p.street != null && p.street!.isNotEmpty) p.street!,
            if (p.locality != null && p.locality!.isNotEmpty) p.locality!,
            if (p.country != null && p.country!.isNotEmpty) p.country!,
          ];
          if (parts.isNotEmpty) address = parts.join(', ');
        }
      } catch (_) {
        // Geocoding failure is non-fatal — we still have coordinates.
      }

      return LocationResult.success(
        latitude: position.latitude,
        longitude: position.longitude,
        address: address,
      );
    } catch (e) {
      return LocationResult.failure('Could not get location: $e');
    }
  }

  /// Shows a two-button dialog and returns `true` if user pressed confirm.
  static Future<bool?> _showDialog(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }
}
