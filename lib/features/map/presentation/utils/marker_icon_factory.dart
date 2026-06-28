import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute, visibleForTesting;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:injectable/injectable.dart';
import 'package:widget_to_marker/widget_to_marker.dart';
import '../../domain/entities/map_user.dart';
import 'map_color_utils.dart';
import '../widgets/map_avatar_marker.dart';

/// Pure-data input for the isolate worker — MUST be isolate-safe (no Flutter
/// handles), per R8/FR-026. Avatar pixel compositing happens off the main
/// thread via `compute()`; only the cheap `BitmapDescriptor.bytes` call
/// happens back on the main isolate.
class _AvatarCompositeJob {
  const _AvatarCompositeJob({
    required this.avatarBytes,
    required this.borderColorValue,
    required this.isOnline,
    required this.hasActiveStatus,
  });

  final Uint8List avatarBytes;
  final int borderColorValue;
  final bool isOnline;
  final bool hasActiveStatus;
}

const _kMarkerSize = 112; // logical px * device-independent scale baked in
const _kBorderWidth = 6;
const _kOnlineDotRadius = 10;
// Distinct from both the per-user border color and the green online dot —
// matches the WhatsApp/Instagram "active story" ring convention.
const _kStatusRingColor = 0xFFFF9800;

/// Decode → crop-to-circle → border + online-dot composite → PNG encode.
/// Runs entirely on plain bytes so it is safe inside a background isolate.
Uint8List _compositeAvatarMarker(_AvatarCompositeJob job) {
  final decoded = img.decodeImage(job.avatarBytes);
  if (decoded == null) {
    throw const FormatException('Could not decode avatar image');
  }

  final resized = img.copyResize(
    decoded,
    width: _kMarkerSize,
    height: _kMarkerSize,
    interpolation: img.Interpolation.average,
  );
  final cropRadius = (_kMarkerSize ~/ 2) - _kBorderWidth;
  var canvas = img.copyCropCircle(resized, radius: cropRadius);

  // Pad back out to full marker size so the border ring isn't clipped.
  final padded = img.Image(width: _kMarkerSize, height: _kMarkerSize, numChannels: 4);
  img.compositeImage(
    padded,
    canvas,
    dstX: (_kMarkerSize - canvas.width) ~/ 2,
    dstY: (_kMarkerSize - canvas.height) ~/ 2,
  );
  canvas = padded;

  if (job.hasActiveStatus) {
    // Outer status ring, drawn first so the per-user border below sits just
    // inside it — same double-ring look WhatsApp/Instagram use for stories.
    canvas = img.drawCircle(
      canvas,
      x: _kMarkerSize ~/ 2,
      y: _kMarkerSize ~/ 2,
      radius: _kMarkerSize ~/ 2 - 1,
      color: img.ColorRgba8(
        (_kStatusRingColor >> 16) & 0xFF,
        (_kStatusRingColor >> 8) & 0xFF,
        _kStatusRingColor & 0xFF,
        255,
      ),
      antialias: true,
    );
  }

  final borderColor = img.ColorRgba8(
    (job.borderColorValue >> 16) & 0xFF,
    (job.borderColorValue >> 8) & 0xFF,
    job.borderColorValue & 0xFF,
    255,
  );
  canvas = img.drawCircle(
    canvas,
    x: _kMarkerSize ~/ 2,
    y: _kMarkerSize ~/ 2,
    radius: cropRadius,
    color: borderColor,
    antialias: true,
  );

  if (job.isOnline) {
    final dotCx = _kMarkerSize - _kOnlineDotRadius - 2;
    final dotCy = _kMarkerSize - _kOnlineDotRadius - 2;
    canvas = img.fillCircle(
      canvas,
      x: dotCx,
      y: dotCy,
      radius: _kOnlineDotRadius + 2,
      color: img.ColorRgba8(255, 255, 255, 255),
    );
    canvas = img.fillCircle(
      canvas,
      x: dotCx,
      y: dotCy,
      radius: _kOnlineDotRadius,
      color: img.ColorRgba8(0x4C, 0xAF, 0x50, 255),
    );
  }

  return img.encodePng(canvas);
}

/// Generates marker `BitmapDescriptor`s for [MapUser]s without freezing the
/// UI (FR-026/SC-010): heavy pixel work (network avatar decode/crop/border
/// compositing) runs off the main thread via `compute()`. The lightweight
/// initial-on-color placeholder (no network fetch) stays on the main isolate
/// via `widget_to_marker` — it is cheap and not the source of jank at scale.
/// Generated icons are cached so panning/zoom never rebuilds them (FR-028).
@lazySingleton
class MarkerIconFactory {
  MarkerIconFactory();

  /// Test-only seam: lets tests substitute a mock [BaseCacheManager] instead
  /// of the real one, which would otherwise need real path_provider/sqflite
  /// plugins to even reach the network call. Not used by DI — the default
  /// (unnamed) constructor above is what `@lazySingleton` generates.
  @visibleForTesting
  MarkerIconFactory.test({required BaseCacheManager cacheManager})
      : _cacheManager = cacheManager;

  // Lazy: constructing DefaultCacheManager() triggers flutter_cache_manager's
  // background file-system setup immediately, which is wasted work for any
  // user with no avatarUrl (and the only realistic placeholder-only case).
  BaseCacheManager? _cacheManager;
  BaseCacheManager get _effectiveCacheManager =>
      _cacheManager ??= DefaultCacheManager();

  static const _maxConcurrent = 4;
  int _inFlight = 0;
  final List<Completer<void>> _waiters = [];

  final Map<String, BitmapDescriptor> _cache = {};

  String _cacheKey(MapUser user) =>
      '${user.id}_${user.avatarUrl}_${user.isOnline}_${user.hasActiveStatus}';

  BitmapDescriptor? cached(MapUser user) => _cache[_cacheKey(user)];

  /// Returns the placeholder immediately, then resolves the real icon
  /// asynchronously via [onResolved] once ready (FR-027 placeholder-first).
  Future<BitmapDescriptor> resolve(
    MapUser user, {
    void Function(BitmapDescriptor icon)? onResolved,
  }) async {
    final key = _cacheKey(user);
    final cachedIcon = _cache[key];
    if (cachedIcon != null) return cachedIcon;

    final placeholder = await MapAvatarMarker(user: user).toBitmapDescriptor();

    final avatarUrl = user.avatarUrl;
    if (avatarUrl == null || avatarUrl.isEmpty) {
      _cache[key] = placeholder;
      return placeholder;
    }

    unawaited(_resolveNetworkIcon(user, key, placeholder, onResolved));
    return placeholder;
  }

  Future<void> _resolveNetworkIcon(
    MapUser user,
    String key,
    BitmapDescriptor placeholder,
    void Function(BitmapDescriptor icon)? onResolved,
  ) async {
    await _acquire();
    try {
      final file = await _effectiveCacheManager.getSingleFile(user.avatarUrl!);
      final bytes = await file.readAsBytes();
      final pngBytes = await compute(
        _compositeAvatarMarker,
        _AvatarCompositeJob(
          avatarBytes: bytes,
          borderColorValue: MapColorUtils.forId(user.id).toARGB32() & 0xFFFFFF,
          isOnline: user.isOnline,
          hasActiveStatus: user.hasActiveStatus,
        ),
      );
      final icon = BitmapDescriptor.bytes(pngBytes);
      _cache[key] = icon;
      onResolved?.call(icon);
    } catch (_) {
      // Network/decoding failure → fallback remains the placeholder (FR-027).
      _cache[key] = placeholder;
    } finally {
      _release();
    }
  }

  Future<void> _acquire() async {
    if (_inFlight < _maxConcurrent) {
      _inFlight++;
      return;
    }
    final completer = Completer<void>();
    _waiters.add(completer);
    await completer.future;
    _inFlight++;
  }

  void _release() {
    _inFlight--;
    if (_waiters.isNotEmpty) {
      _waiters.removeAt(0).complete();
    }
  }

  void clear() => _cache.clear();
}
