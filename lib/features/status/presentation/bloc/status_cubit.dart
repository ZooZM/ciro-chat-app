import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_entity.dart';
import 'package:ciro_chat_app/features/status/domain/repositories/status_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

part 'status_state.dart';

@injectable
class StatusCubit extends Cubit<StatusState> {
  final StatusRepository repository;
  StreamSubscription? _statusSubscription;
  Timer? _expiryTimer;

  StatusCubit(this.repository) : super(StatusInitial()) {
    _startExpiryTimer();
  }

  void _startExpiryTimer() {
    _expiryTimer?.cancel();
    _expiryTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      repository.purgeExpiredStatuses().then((_) {
        // Reload statuses to refresh UI if anything expired
        if (state is StatusLoaded) {
          loadRecentStatuses();
        }
      });
    });
  }

  Future<void> loadRecentStatuses() async {
    emit(StatusLoading());
    final recentResult = await repository.getRecentStatuses();
    final viewedResult = await repository.getViewedStatuses();
    final myStatusResult = await repository.getMyStatus();
    
    recentResult.fold(
      (failure) => emit(StatusError(failure.message)),
      (recentStatuses) {
        viewedResult.fold(
          (failure) => emit(StatusError(failure.message)),
          (viewedStatuses) {
            myStatusResult.fold(
              (failure) => emit(StatusError(failure.message)),
              (myStatus) {
                emit(StatusLoaded(
                  recentStatuses: recentStatuses,
                  viewedStatuses: viewedStatuses,
                  myStatus: myStatus,
                ));
                _listenToStatusStream();
              },
            );
          },
        );
      },
    );
  }

  Future<void> uploadNewStatus({
    required String content, // text or image url
    required String authorName,
    required String authorAvatar,
  }) async {
    if (state is StatusLoaded) {
      final currentState = state as StatusLoaded;
      
      final now = DateTime.now();
      final newStatus = StatusEntity(
        id: DateTime.now().millisecondsSinceEpoch.toString(), // Temp ID
        authorName: authorName,
        authorAvatar: authorAvatar,
        timestamp: now,
        expiresAt: now.add(const Duration(hours: 24)),
        isViewed: true, // Own status
        isMine: true,
      );

      emit(currentState.copyWith(myStatus: newStatus));

      final result = await repository.addStatus(newStatus);
      result.fold(
        (failure) {
          // Fallback if failed
          emit(currentState);
        },
        (_) {},
      );
    }
  }

  Future<void> markStatusAsViewed(String statusId) async {
    if (state is StatusLoaded) {
      final currentState = state as StatusLoaded;
      
      // Optimistic update
      final statusToUpdate = currentState.recentStatuses.firstWhere((s) => s.id == statusId);
      final updatedStatus = StatusEntity(
        id: statusToUpdate.id,
        authorName: statusToUpdate.authorName,
        authorAvatar: statusToUpdate.authorAvatar,
        timestamp: statusToUpdate.timestamp,
        expiresAt: statusToUpdate.expiresAt,
        isViewed: true,
        isMine: statusToUpdate.isMine,
      );

      final updatedRecent = List<StatusEntity>.from(currentState.recentStatuses)..removeWhere((s) => s.id == statusId);
      final updatedViewed = List<StatusEntity>.from(currentState.viewedStatuses)..insert(0, updatedStatus);
      
      emit(currentState.copyWith(recentStatuses: updatedRecent, viewedStatuses: updatedViewed));

      // Network request
      final result = await repository.markAsViewed(statusId);
      result.fold(
        (failure) {
          // Revert on failure (simplified)
          emit(currentState);
        },
        (_) {},
      );
    }
  }

  void searchStatuses(String query) {
    if (state is StatusLoaded) {
      final currentState = state as StatusLoaded;
      emit(currentState.copyWith(searchQuery: query));
    }
  }

  void _listenToStatusStream() {
    _statusSubscription?.cancel();
    _statusSubscription = repository.statusStream.listen((status) {
      if (state is StatusLoaded) {
        final currentState = state as StatusLoaded;
        final updatedRecent = List<StatusEntity>.from(currentState.recentStatuses)
          ..removeWhere((s) => s.id == status.id)
          ..insert(0, status);
        emit(currentState.copyWith(recentStatuses: updatedRecent));
      }
    });
  }

  @override
  Future<void> close() {
    _statusSubscription?.cancel();
    _expiryTimer?.cancel();
    return super.close();
  }
}
