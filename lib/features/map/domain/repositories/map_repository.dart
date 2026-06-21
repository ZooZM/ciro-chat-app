import 'package:fpdart/fpdart.dart';
import 'package:ciro_chat_app/core/error/failures.dart';
import '../entities/map_user.dart';
import '../entities/map_group.dart';

/// Live signal that `userId`'s presence changed (FR-002/003).
typedef PresenceUpdate = ({String userId, bool isOnline});

/// A single batched location/visibility item (FR-006a contract).
class LocationUpdate {
  const LocationUpdate({
    required this.userId,
    required this.longitude,
    required this.latitude,
    required this.isOnline,
    required this.lastUpdatedAt,
  });

  final String userId;
  final double longitude;
  final double latitude;
  final bool isOnline;
  final DateTime lastUpdatedAt;
}

abstract class MapRepository {
  /// Full authorized set (non-distance-limited) — "All Locations" (FR-018).
  Future<Either<Failure, List<MapUser>>> getVisibleUsers();

  /// Authorized set within `radiusKm` of (longitude, latitude) — "Nearby Only".
  Future<Either<Failure, List<MapUser>>> getNearbyUsers({
    required double longitude,
    required double latitude,
    required double radiusKm,
  });

  /// Explore tab: SHOW_ON_MAP statuses, coarse for non-contacts (FR-001a/b).
  Future<Either<Failure, List<MapUser>>> getExploreUsers();

  /// The caller's GROUP chat rooms, for the group filter (FR-017/023).
  Future<Either<Failure, List<MapGroup>>> getGroups();

  Future<Either<Failure, bool>> setGhostMode(bool enabled);
  Future<Either<Failure, bool>> getGhostMode();

  /// Throttled live-location broadcast over the socket (FR-006, R4).
  void shareLocation({required double longitude, required double latitude});

  /// Live presence changes for authorized contacts (FR-002/003/004).
  Stream<PresenceUpdate> get presenceUpdates;

  /// Batched live location/visibility changes (FR-006a).
  Stream<List<LocationUpdate>> get locationUpdates;

  /// Fired when an authorized contact's marker must be removed (Ghost Mode
  /// enabled, or otherwise stopped sharing) — FR-012.
  Stream<String> get locationHidden;

  /// Cancels all subscriptions and unregisters socket callbacks (Constitution V).
  void dispose();
}
