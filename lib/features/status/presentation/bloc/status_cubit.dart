import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_entity.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_reaction.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_viewer.dart';
import 'package:ciro_chat_app/features/status/domain/repositories/status_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

part 'status_state.dart';

@injectable
class StatusCubit extends Cubit<StatusState> {
  final StatusRepository repository;
  StreamSubscription? _statusSubscription;
  StreamSubscription? _viewerAddedSubscription;
  StreamSubscription? _reactedSubscription;
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
    final myStatusesResult = await repository.getMyStatuses();

    recentResult.fold(
      (failure) => emit(StatusError(failure.message)),
      (recentStatuses) {
        viewedResult.fold(
          (failure) => emit(StatusError(failure.message)),
          (viewedStatuses) {
            myStatusesResult.fold(
              (failure) => emit(StatusError(failure.message)),
              (myStatuses) {
                emit(StatusLoaded(
                  recentStatuses: recentStatuses,
                  viewedStatuses: viewedStatuses,
                  myStatuses: myStatuses,
                ));
                _listenToStatusStream();
                _listenToMyStatusUpdates();
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

      emit(currentState.copyWith(
        myStatuses: [...currentState.myStatuses, newStatus],
      ));

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

      // Optimistic update — only move if the status is still in the unviewed list.
      final statusToUpdate = currentState.recentStatuses
          .cast<StatusEntity?>()
          .firstWhere((s) => s?.id == statusId, orElse: () => null);

      if (statusToUpdate != null) {
        final updatedStatus = statusToUpdate.copyWith(isViewed: true);
        final updatedRecent = List<StatusEntity>.from(currentState.recentStatuses)
          ..removeWhere((s) => s.id == statusId);
        final updatedViewed = List<StatusEntity>.from(currentState.viewedStatuses)
          ..insert(0, updatedStatus);
        emit(currentState.copyWith(recentStatuses: updatedRecent, viewedStatuses: updatedViewed));
      }

      // Don't notify the server when the owner views their own status — the
      // server tracks viewers from other users, not self-views.
      final isOwn = currentState.myStatuses.any((s) => s.id == statusId);
      if (!isOwn) {
        final result = await repository.markAsViewed(statusId);
        result.fold(
          (failure) {
            if (statusToUpdate != null) emit(currentState);
          },
          (_) {},
        );
      }
    }
  }

  Future<void> react(String statusId, String reaction) async {
    await repository.react(statusId, reaction);
  }

  Future<void> reply(String statusId, String message) async {
    await repository.reply(statusId, message);
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
        if (status.isMine) {
          // Own status echoed back (e.g. via socket) — append/replace it in
          // "My status" instead of overwriting the whole list, then keep
          // the list in chronological order for the story viewer.
          final updatedMyStatuses = List<StatusEntity>.from(currentState.myStatuses)
            ..removeWhere((s) => s.id == status.id)
            ..add(status)
            ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
          emit(currentState.copyWith(myStatuses: updatedMyStatuses));
          return;
        }
        final updatedRecent = List<StatusEntity>.from(currentState.recentStatuses)
          ..removeWhere((s) => s.id == status.id)
          ..insert(0, status);
        emit(currentState.copyWith(recentStatuses: updatedRecent));
      }
    });
  }

  void _listenToMyStatusUpdates() {
    _viewerAddedSubscription?.cancel();
    _viewerAddedSubscription = repository.statusViewerAddedStream.listen((event) {
      if (state is StatusLoaded) {
        final currentState = state as StatusLoaded;
        final myStatuses = currentState.myStatuses;
        final index = myStatuses.indexWhere((s) => s.id == event.statusId);
        if (index == -1) return;

        final target = myStatuses[index];
        final updatedViewers = List<StatusViewer>.from(target.viewers)
          ..removeWhere((v) => v.userId == event.viewer.userId)
          ..add(event.viewer);
        final updatedMyStatuses = List<StatusEntity>.from(myStatuses);
        updatedMyStatuses[index] = target.copyWith(viewers: updatedViewers);
        emit(currentState.copyWith(myStatuses: updatedMyStatuses));
      }
    });

    _reactedSubscription?.cancel();
    _reactedSubscription = repository.statusReactedStream.listen((event) {
      if (state is StatusLoaded) {
        final currentState = state as StatusLoaded;
        final myStatuses = currentState.myStatuses;
        final index = myStatuses.indexWhere((s) => s.id == event.statusId);
        if (index == -1) return;

        final target = myStatuses[index];
        final updatedReactions = List<StatusReaction>.from(target.reactions)
          ..removeWhere((r) => r.userId == event.reaction.userId)
          ..add(event.reaction);
        final updatedMyStatuses = List<StatusEntity>.from(myStatuses);
        updatedMyStatuses[index] = target.copyWith(reactions: updatedReactions);
        emit(currentState.copyWith(myStatuses: updatedMyStatuses));
      }
    });
  }

  @override
  Future<void> close() {
    _statusSubscription?.cancel();
    _viewerAddedSubscription?.cancel();
    _reactedSubscription?.cancel();
    _expiryTimer?.cancel();
    return super.close();
  }
}
