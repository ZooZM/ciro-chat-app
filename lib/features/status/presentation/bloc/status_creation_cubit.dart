import 'package:ciro_chat_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_content_type.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_entity.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_privacy.dart';
import 'package:ciro_chat_app/features/status/domain/repositories/status_repository.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:ciro_chat_app/features/status/presentation/bloc/status_creation_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';

@injectable
class StatusCreationCubit extends Cubit<StatusCreationState> {
  final StatusRepository statusRepository;
  final AuthCubit authCubit;
  late final RecorderController recorderController;
  bool isRecording = false;

  StatusCreationCubit({
    required this.statusRepository,
    required this.authCubit,
  }) : super(StatusCreationIdle()) {
    recorderController = RecorderController();
  }

  void initDraft(StatusContentType mode) {
    String authorName = 'Unknown';
    String authorAvatar = '';
    
    if (authCubit.state is Authenticated) {
      final userData = (authCubit.state as Authenticated).userData;
      if (userData != null) {
        authorName = userData['name'] ?? 'Unknown';
        authorAvatar = userData['avatarUrl'] ?? '';
      }
    }

    final draft = StatusEntity(
      id: const Uuid().v4(),
      authorName: authorName,
      authorAvatar: authorAvatar,
      timestamp: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(hours: 24)),
      contentType: mode,
      isMine: true,
      backgroundColor: '#FF5722', // default color
    );
    emit(StatusCreationComposing(draft));
  }

  void switchMode(StatusContentType mode) {
    if (state is StatusCreationComposing) {
      final currentDraft = (state as StatusCreationComposing).draft;
      final updatedDraft = StatusEntity(
        id: currentDraft.id,
        authorName: currentDraft.authorName,
        authorAvatar: currentDraft.authorAvatar,
        timestamp: currentDraft.timestamp,
        expiresAt: currentDraft.expiresAt,
        contentType: mode,
        textContent: currentDraft.textContent,
        mediaUrl: currentDraft.mediaUrl,
        backgroundColor: currentDraft.backgroundColor,
        fontStyle: currentDraft.fontStyle,
        musicTrackId: currentDraft.musicTrackId,
        caption: currentDraft.caption,
        privacy: currentDraft.privacy,
        isMine: true,
      );
      emit(StatusCreationComposing(updatedDraft));
    } else {
      initDraft(mode);
    }
  }

  void updateText(String text) {
    _updateDraft((draft) => StatusEntity(
          id: draft.id,
          authorName: draft.authorName,
          authorAvatar: draft.authorAvatar,
          timestamp: draft.timestamp,
          expiresAt: draft.expiresAt,
          contentType: draft.contentType,
          textContent: text,
          mediaUrl: draft.mediaUrl,
          backgroundColor: draft.backgroundColor,
          fontStyle: draft.fontStyle,
          musicTrackId: draft.musicTrackId,
          caption: draft.caption,
          privacy: draft.privacy,
          isMine: true,
        ));
  }

  void updateBackgroundColor(String colorHex) {
    _updateDraft((draft) => StatusEntity(
          id: draft.id,
          authorName: draft.authorName,
          authorAvatar: draft.authorAvatar,
          timestamp: draft.timestamp,
          expiresAt: draft.expiresAt,
          contentType: draft.contentType,
          textContent: draft.textContent,
          mediaUrl: draft.mediaUrl,
          backgroundColor: colorHex,
          fontStyle: draft.fontStyle,
          musicTrackId: draft.musicTrackId,
          caption: draft.caption,
          privacy: draft.privacy,
          isMine: true,
        ));
  }

  void updateFontStyle(String fontStyle) {
    _updateDraft((draft) => StatusEntity(
          id: draft.id,
          authorName: draft.authorName,
          authorAvatar: draft.authorAvatar,
          timestamp: draft.timestamp,
          expiresAt: draft.expiresAt,
          contentType: draft.contentType,
          textContent: draft.textContent,
          mediaUrl: draft.mediaUrl,
          backgroundColor: draft.backgroundColor,
          fontStyle: fontStyle,
          musicTrackId: draft.musicTrackId,
          caption: draft.caption,
          privacy: draft.privacy,
          isMine: true,
        ));
  }

  void updatePrivacy(StatusPrivacy privacy) {
    _updateDraft((draft) => StatusEntity(
          id: draft.id,
          authorName: draft.authorName,
          authorAvatar: draft.authorAvatar,
          timestamp: draft.timestamp,
          expiresAt: draft.expiresAt,
          contentType: draft.contentType,
          textContent: draft.textContent,
          mediaUrl: draft.mediaUrl,
          backgroundColor: draft.backgroundColor,
          fontStyle: draft.fontStyle,
          musicTrackId: draft.musicTrackId,
          caption: draft.caption,
          privacy: privacy,
          isMine: true,
        ));
  }

  void attachMedia(String mediaUrl, StatusContentType type) {
    _updateDraft((draft) => StatusEntity(
          id: draft.id,
          authorName: draft.authorName,
          authorAvatar: draft.authorAvatar,
          timestamp: draft.timestamp,
          expiresAt: draft.expiresAt,
          contentType: type,
          textContent: draft.textContent,
          mediaUrl: mediaUrl,
          backgroundColor: draft.backgroundColor,
          fontStyle: draft.fontStyle,
          musicTrackId: draft.musicTrackId,
          caption: draft.caption,
          privacy: draft.privacy,
          isMine: true,
        ));
  }

  void attachVoiceRecording(String filePath) {
    attachMedia(filePath, StatusContentType.voice);
  }

  Future<void> startRecording() async {
    final hasPermission = await recorderController.checkPermission();
    if (hasPermission) {
      await recorderController.record();
      isRecording = true;
      // Trigger a state emission to update UI if needed
      _updateDraft((d) => d); 
    }
  }

  Future<String?> stopRecording() async {
    final path = await recorderController.stop();
    isRecording = false;
    if (path != null) {
      attachVoiceRecording(path);
    }
    return path;
  }

  void attachMusicTrack(String trackId) {
    _updateDraft((draft) => StatusEntity(
          id: draft.id,
          authorName: draft.authorName,
          authorAvatar: draft.authorAvatar,
          timestamp: draft.timestamp,
          expiresAt: draft.expiresAt,
          contentType: draft.contentType,
          textContent: draft.textContent,
          mediaUrl: draft.mediaUrl,
          backgroundColor: draft.backgroundColor,
          fontStyle: draft.fontStyle,
          musicTrackId: trackId,
          caption: draft.caption,
          privacy: draft.privacy,
          isMine: true,
        ));
  }

  void attachAIImage(String imageUrl) {
    attachMedia(imageUrl, StatusContentType.image);
  }

  Future<void> submitStatus() async {
    if (state is StatusCreationComposing) {
      final draft = (state as StatusCreationComposing).draft;
      emit(StatusCreationUploading(draft));
      
      final result = await statusRepository.uploadStatus(draft);
      result.fold(
        (failure) => emit(StatusCreationError(failure.message)),
        (_) => emit(StatusCreationSuccess()),
      );
    }
  }

  void reset() {
    emit(StatusCreationIdle());
  }

  void _updateDraft(StatusEntity Function(StatusEntity current) updater) {
    if (state is StatusCreationComposing) {
      final currentDraft = (state as StatusCreationComposing).draft;
      emit(StatusCreationComposing(updater(currentDraft)));
    }
  }

  @override
  Future<void> close() {
    recorderController.dispose();
    return super.close();
  }
}
