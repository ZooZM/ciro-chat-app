import 'package:equatable/equatable.dart';

/// A chat group the user belongs to, used for the map group filter
/// (FR-017/023). Replaces the mock group list in the filter sheet.
class MapGroup extends Equatable {
  const MapGroup({
    required this.id,
    required this.name,
    required this.memberCount,
    this.avatarUrl,
    required this.initials,
  });

  final String id;
  final String name;
  final int memberCount;
  final String? avatarUrl;
  final String initials;

  @override
  List<Object?> get props => [id, name, memberCount, avatarUrl, initials];
}
