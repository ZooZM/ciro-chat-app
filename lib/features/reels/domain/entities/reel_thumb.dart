import 'package:equatable/equatable.dart';
import 'reel_status.dart';

/// A single grid cell on the Creator Profile screen (FR-025).
class ReelThumb extends Equatable {
  const ReelThumb({
    required this.id,
    required this.thumbnailUrl,
    this.status = ReelStatus.published,
  });

  final String id;
  final String thumbnailUrl;

  /// v3 (FR-065): only meaningful on the owner's own grid — non-self grids
  /// only ever contain published items.
  final ReelStatus status;

  @override
  List<Object?> get props => [id, thumbnailUrl, status];
}
