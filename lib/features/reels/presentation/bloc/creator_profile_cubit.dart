import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/creator_profile.dart';
import 'package:ciro_chat_app/features/reels/domain/entities/reel.dart';
import 'package:ciro_chat_app/features/reels/domain/repositories/reels_repository.dart';
import 'reels_interaction_cubit.dart';

enum CreatorProfileStatus { initial, loading, ready, error }

/// Lazy-loaded state for the owner-only Liked/Saved tabs (US8) — absent
/// (`null`) until the tab is first opened.
enum SelfTabStatus { loading, ready, error }

class SelfTabState extends Equatable {
  const SelfTabState({required this.status, this.videos = const []});

  final SelfTabStatus status;
  final List<Reel> videos;

  @override
  List<Object?> get props => [status, videos];
}

class CreatorProfileState extends Equatable {
  const CreatorProfileState({
    this.status = CreatorProfileStatus.initial,
    this.profile,
    this.likedTab,
    this.savedTab,
    this.repostedTab,
  });

  final CreatorProfileStatus status;
  final CreatorProfile? profile;

  /// Owner-only (FR-050/051) — never populated for a non-self profile.
  final SelfTabState? likedTab;
  final SelfTabState? savedTab;

  /// v6: public Reposts tab — populated for ANY profile (self or not), since
  /// reposting is a public distribution mechanic.
  final SelfTabState? repostedTab;

  CreatorProfileState copyWith({
    CreatorProfileStatus? status,
    CreatorProfile? profile,
    SelfTabState? likedTab,
    SelfTabState? savedTab,
    SelfTabState? repostedTab,
  }) {
    return CreatorProfileState(
      status: status ?? this.status,
      profile: profile ?? this.profile,
      likedTab: likedTab ?? this.likedTab,
      savedTab: savedTab ?? this.savedTab,
      repostedTab: repostedTab ?? this.repostedTab,
    );
  }

  @override
  List<Object?> get props => [status, profile, likedTab, savedTab, repostedTab];
}

/// `@injectable` (not session-scoped) — a fresh instance per profile screen
/// push, since the user may navigate to several different creators' profiles
/// in one session (FR-023).
@injectable
class CreatorProfileCubit extends Cubit<CreatorProfileState> {
  CreatorProfileCubit(this._repository, this._interactionCubit)
      : super(const CreatorProfileState());

  final ReelsRepository _repository;
  final ReelsInteractionCubit _interactionCubit;

  Future<void> load(String userId) async {
    emit(state.copyWith(status: CreatorProfileStatus.loading));
    final result = await _repository.fetchProfile(userId);
    result.fold(
      (failure) => emit(state.copyWith(status: CreatorProfileStatus.error)),
      (profile) {
        emit(state.copyWith(status: CreatorProfileStatus.ready, profile: profile));
        _interactionCubit.seedFollow(
          profile.id,
          following: profile.viewerFollowing,
          followersCount: profile.followersCount,
        );
      },
    );
  }

  /// Lazily fetches the caller's Liked Videos tab (US8, FR-051) — only ever
  /// called when `profile.isSelf` (owner-only privacy enforced by the UI;
  /// the backend is also caller-scoped regardless).
  Future<void> loadLikedTab() async {
    if (state.likedTab != null) return;
    emit(state.copyWith(likedTab: const SelfTabState(status: SelfTabStatus.loading)));
    final result = await _repository.fetchLiked();
    result.fold(
      (failure) => emit(state.copyWith(likedTab: const SelfTabState(status: SelfTabStatus.error))),
      (page) => emit(
        state.copyWith(likedTab: SelfTabState(status: SelfTabStatus.ready, videos: page.items)),
      ),
    );
  }

  /// Lazily fetches the caller's Saved Videos tab (US8, FR-050).
  Future<void> loadSavedTab() async {
    if (state.savedTab != null) return;
    emit(state.copyWith(savedTab: const SelfTabState(status: SelfTabStatus.loading)));
    final result = await _repository.fetchSaved();
    result.fold(
      (failure) => emit(state.copyWith(savedTab: const SelfTabState(status: SelfTabStatus.error))),
      (page) => emit(
        state.copyWith(savedTab: SelfTabState(status: SelfTabStatus.ready, videos: page.items)),
      ),
    );
  }

  /// v6: lazily fetches the viewed profile's public Reposts tab. Unlike
  /// liked/saved this targets the profile owner (`state.profile.id`), not the
  /// caller — reposts are public.
  Future<void> loadRepostedTab() async {
    if (state.repostedTab != null) return;
    final userId = state.profile?.id;
    if (userId == null) return;
    emit(state.copyWith(repostedTab: const SelfTabState(status: SelfTabStatus.loading)));
    final result = await _repository.fetchReposted(userId: userId);
    result.fold(
      (failure) =>
          emit(state.copyWith(repostedTab: const SelfTabState(status: SelfTabStatus.error))),
      (page) => emit(
        state.copyWith(repostedTab: SelfTabState(status: SelfTabStatus.ready, videos: page.items)),
      ),
    );
  }

  /// FR-052: toggles the block relationship with the viewed profile.
  Future<bool> toggleBlock() async {
    final profile = state.profile;
    if (profile == null) return false;
    final result = await _repository.toggleBlock(profile.id);
    return result.fold((_) => false, (blocked) => blocked);
  }

  /// v3 (FR-067): owner-only, any status. Removes the item from the own
  /// grid on success; caller (the UI) surfaces failure as a non-intrusive
  /// notice per FR-037's pattern.
  Future<bool> deleteReel(String reelId) async {
    final profile = state.profile;
    if (profile == null) return false;
    final result = await _repository.deleteReel(reelId);
    return result.fold((_) => false, (_) {
      emit(
        state.copyWith(
          profile: profile.copyWith(
            videos: profile.videos.where((v) => v.id != reelId).toList(),
          ),
        ),
      );
      return true;
    });
  }
}
