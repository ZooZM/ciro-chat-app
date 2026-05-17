import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionRequestResult {
  final bool allGranted;
  final List<Permission> permanentlyDenied;
  final List<Permission> denied;

  const PermissionRequestResult({
    required this.allGranted,
    required this.permanentlyDenied,
    required this.denied,
  });
}

class PermissionService {
  static const List<Permission> _requiredPermissions = [
    Permission.contacts,
    Permission.camera,
    Permission.microphone,
    Permission.photos,
    Permission.storage,
    Permission.notification,
  ];

  // Serializes all permission_handler requests: only one .request() call may
  // be in flight at a time. Two concurrent calls throw PlatformException.
  static Future<void>? _ongoingRequest;

  static Future<T> _serialized<T>(Future<T> Function() fn) async {
    while (_ongoingRequest != null) {
      await _ongoingRequest;
    }
    final completer = Completer<void>();
    _ongoingRequest = completer.future;
    try {
      return await fn();
    } finally {
      _ongoingRequest = null;
      completer.complete();
    }
  }

  /// Requests a single [permission] safely, serialized with all other requests.
  /// Returns true if granted. Skips the native dialog if already granted.
  static Future<bool> requestSingle(Permission permission) {
    return _serialized(() async {
      final status = await permission.status;
      if (status.isGranted) return true;
      final result = await permission.request();
      return result.isGranted;
    });
  }

  /// Request all required permissions in bulk.
  /// Returns a [PermissionRequestResult] detailing what was granted/denied.
  Future<PermissionRequestResult> requestAll() {
    return _serialized(() async {
      Map<Permission, PermissionStatus> statuses;
      try {
        statuses = await _requiredPermissions.request();
      } on PlatformException {
        // permission_handler_android 13+ can throw if the Activity binding
        // isn't ready yet (e.g. immediately after a hot restart). Retry once.
        await Future.delayed(const Duration(milliseconds: 300));
        statuses = await _requiredPermissions.request();
      }

      final permanentlyDenied = <Permission>[];
      final denied = <Permission>[];

      for (final permission in _requiredPermissions) {
        final status = statuses[permission];
        if (status == null) continue;

        if (status.isPermanentlyDenied) {
          permanentlyDenied.add(permission);
        } else if (status.isDenied) {
          denied.add(permission);
        }
      }

      return PermissionRequestResult(
        allGranted: permanentlyDenied.isEmpty && denied.isEmpty,
        permanentlyDenied: permanentlyDenied,
        denied: denied,
      );
    });
  }

  static String labelFor(Permission permission) {
    switch (permission) {
      case Permission.contacts:
        return 'Contacts';
      case Permission.camera:
        return 'Camera';
      case Permission.microphone:
        return 'Microphone';
      case Permission.photos:
        return 'Photos';
      case Permission.storage:
        return 'Storage';
      case Permission.notification:
        return 'Notifications';
      default:
        return 'Required Permission';
    }
  }
}

/// Mixin to be used on any StatefulWidget that needs to trigger the permission
/// flow and handle the result gracefully.
mixin PermissionHandlerMixin<T extends StatefulWidget> on State<T> {
  final PermissionService _permissionService = PermissionService();

  Future<void> requestAppPermissions() async {
    final result = await _permissionService.requestAll();

    if (!mounted) return;

    if (result.allGranted) return;

    if (result.permanentlyDenied.isNotEmpty) {
      await _showPermanentlyDeniedDialog(result.permanentlyDenied);
      return;
    }

    if (result.denied.isNotEmpty) {
      final names = result.denied.map(PermissionService.labelFor).join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Some features may be limited. Denied: $names.'),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: requestAppPermissions,
          ),
        ),
      );
    }
  }

  Future<void> _showPermanentlyDeniedDialog(List<Permission> permissions) async {
    final names = permissions.map(PermissionService.labelFor).join(', ');

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_outline, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Permissions Required'),
          ],
        ),
        content: Text(
          'The following permissions were permanently denied:\n\n$names\n\n'
          'Please open Settings and grant them to use Ciro Connect fully.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Later'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}
