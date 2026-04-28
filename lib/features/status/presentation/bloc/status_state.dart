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
  final StatusEntity? myStatus;
  final String searchQuery;

  const StatusLoaded({
    required this.recentStatuses,
    required this.viewedStatuses,
    this.myStatus,
    this.searchQuery = '',
  });

  @override
  List<Object?> get props => [
        recentStatuses,
        viewedStatuses,
        myStatus,
        searchQuery,
      ];

  StatusLoaded copyWith({
    List<StatusEntity>? recentStatuses,
    List<StatusEntity>? viewedStatuses,
    StatusEntity? myStatus,
    String? searchQuery,
  }) {
    return StatusLoaded(
      recentStatuses: recentStatuses ?? this.recentStatuses,
      viewedStatuses: viewedStatuses ?? this.viewedStatuses,
      myStatus: myStatus ?? this.myStatus,
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
