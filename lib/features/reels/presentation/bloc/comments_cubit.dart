import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/reel_comment.dart';
import 'package:ciro_chat_app/features/reels/domain/repositories/reels_repository.dart';
import 'reels_interaction_cubit.dart';

enum CommentsStatus { initial, loading, ready, error }

class CommentsState extends Equatable {
  const CommentsState({
    this.status = CommentsStatus.initial,
    this.comments = const [],
    this.posting = false,
    this.postError = false,
  });

  final CommentsStatus status;
  final List<ReelComment> comments;
  final bool posting;
  final bool postError;

  CommentsState copyWith({
    CommentsStatus? status,
    List<ReelComment>? comments,
    bool? posting,
    bool? postError,
  }) {
    return CommentsState(
      status: status ?? this.status,
      comments: comments ?? this.comments,
      posting: posting ?? this.posting,
      postError: postError ?? false,
    );
  }

  @override
  List<Object?> get props => [status, comments, posting, postError];
}

/// Per-sheet lifecycle: created when the comment bottom sheet opens, closed
/// (and disposed) when it closes (FR-019/FR-020) — unlike the session-scoped
/// feed/interaction singletons, this is `@injectable` (a fresh instance per
/// sheet open).
@injectable
class CommentsCubit extends Cubit<CommentsState> {
  CommentsCubit(this._repository, this._interactionCubit) : super(const CommentsState());

  final ReelsRepository _repository;
  final ReelsInteractionCubit _interactionCubit;

  String? _reelId;

  Future<void> load(String reelId) async {
    _reelId = reelId;
    emit(state.copyWith(status: CommentsStatus.loading));
    final result = await _repository.fetchComments(reelId);
    result.fold(
      (failure) => emit(state.copyWith(status: CommentsStatus.error)),
      (page) {
        emit(state.copyWith(status: CommentsStatus.ready, comments: page.items));
        _interactionCubit.setCommentCount(reelId, page.commentsCount);
      },
    );
  }

  Future<void> post(String text) async {
    final reelId = _reelId;
    final trimmed = text.trim();
    if (reelId == null || trimmed.isEmpty) return;
    emit(state.copyWith(posting: true, postError: false));
    final result = await _repository.postComment(reelId, trimmed);
    result.fold(
      (failure) => emit(state.copyWith(posting: false, postError: true)),
      (result) {
        emit(
          state.copyWith(
            posting: false,
            comments: [result.comment, ...state.comments],
          ),
        );
        _interactionCubit.setCommentCount(reelId, result.commentsCount);
      },
    );
  }
}
