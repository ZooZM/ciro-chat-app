part of 'status_cubit.dart';

sealed class StatusState extends Equatable {
  const StatusState();

  @override
  List<Object?> get props => [];
}

class StatusInitial extends StatusState {}

class StatusLoading extends StatusState {}

class StatusLoaded extends StatusState {
  final List<StatusEntity> recentStatuses;
  final List<StatusEntity> viewedStatuses;
  final List<StatusEntity> myStatuses;
  final String searchQuery;

  const StatusLoaded({
    required this.recentStatuses,
    required this.viewedStatuses,
    this.myStatuses = const [],
    this.searchQuery = '',
  });

  @override
  List<Object?> get props => [
        recentStatuses,
        viewedStatuses,
        myStatuses,
        searchQuery,
      ];

  /// Every "other" status grouped by [StatusEntity.authorId], each group
  /// sorted chronologically (oldest first) so the story viewer can page
  /// through an author's full set of active statuses in posting order.
  Map<String, List<StatusEntity>> get statusGroups {
    final groups = <String, List<StatusEntity>>{};
    for (final status in [...recentStatuses, ...viewedStatuses]) {
      groups.putIfAbsent(status.authorId, () => []).add(status);
    }
    for (final group in groups.values) {
      group.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    }
    return groups;
  }

  StatusLoaded copyWith({
    List<StatusEntity>? recentStatuses,
    List<StatusEntity>? viewedStatuses,
    List<StatusEntity>? myStatuses,
    String? searchQuery,
  }) {
    return StatusLoaded(
      recentStatuses: recentStatuses ?? this.recentStatuses,
      viewedStatuses: viewedStatuses ?? this.viewedStatuses,
      myStatuses: myStatuses ?? this.myStatuses,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class StatusError extends StatusState {
  final String message;

  const StatusError(this.message);

  @override
  List<Object> get props => [message];
}
