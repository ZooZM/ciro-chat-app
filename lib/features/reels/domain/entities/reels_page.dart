import 'package:equatable/equatable.dart';
import 'reel.dart';

class ReelsPage extends Equatable {
  const ReelsPage({required this.items, required this.nextCursor});

  final List<Reel> items;

  /// `null` means no more pages (only possible for the creator-scoped feed —
  /// the main feed loops the catalog and never returns `null`, FR-007).
  final String? nextCursor;

  @override
  List<Object?> get props => [items, nextCursor];
}
