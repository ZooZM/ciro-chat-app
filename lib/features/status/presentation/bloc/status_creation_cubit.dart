import 'package:ciro_chat_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:ciro_chat_app/features/map/data/datasources/map_location_service.dart';
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
  final MapLocationService locationService;
  late final RecorderController recorderController;
  bool isRecording = false;

  StatusCreationCubit({
    required this.statusRepository,
    required this.authCubit,
    required this.locationService,
  }) : super(StatusCreationIdle()) {
    recorderController = RecorderController();
  }

  Future<void> initDraft(StatusContentType mode) async {
    // `authCubit.state.userData` is only populated right after a fresh OTP
    // login — reopening the app with an already-valid session leaves it
    // null, which used to fall straight through to the "Unknown" default.
    final authorName = await authCubit.getCurrentUserName() ?? 'Unknown';
    String authorAvatar = '';
    if (authCubit.state is Authenticated) {
      authorAvatar = (authCubit.state as Authenticated).userData?['avatarUrl'] ?? '';
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
      emit(StatusCreationComposing(currentDraft.copyWith(contentType: mode)));
    } else {
      initDraft(mode);
    }
  }

  void updateText(String text) {
    _updateDraft((draft) => draft.copyWith(textContent: text));
  }

  void updateBackgroundColor(String colorHex) {
    _updateDraft((draft) => draft.copyWith(backgroundColor: colorHex));
  }

  void updateFontStyle(String fontStyle) {
    _updateDraft((draft) => draft.copyWith(fontStyle: fontStyle));
  }

  /// T053: switching to "private" pre-selects the user's cached/fetched
  /// default audience (T052) so the upload carries a sensible `audience`
  /// without requiring a new contact-picker UI (SC-007).
  Future<void> updatePrivacy(StatusPrivacy privacy) async {
    _updateDraft((draft) => draft.copyWith(privacy: privacy));

    if (privacy != StatusPrivacy.private) return;
    final draft = (state as StatusCreationComposing).draft;
    if (draft.audience.isNotEmpty) return;

    final result = await statusRepository.getDefaultAudience();
    result.fold(
      (_) {},
      (contacts) => _updateDraft(
        (draft) => draft.copyWith(
          audience: contacts.map((c) => c.userId).toList(),
        ),
      ),
    );
  }

  void attachMedia(String mediaUrl, StatusContentType type) {
    _updateDraft((draft) => draft.copyWith(contentType: type, mediaUrl: mediaUrl));
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
    _updateDraft((draft) => draft.copyWith(musicTrackId: trackId));
  }

  void attachAIImage(String imageUrl) {
    attachMedia(imageUrl, StatusContentType.image);
  }

  Future<void> submitStatus() async {
    if (state is StatusCreationComposing) {
      // Refresh the timestamp to the moment of actual submission — the draft
      // was created when the composer screen opened, which can be well
      // before the user finishes typing/picking media and hits send.
      final now = DateTime.now();
      var draft = (state as StatusCreationComposing).draft.copyWith(
        timestamp: now,
        expiresAt: now.add(const Duration(hours: 24)),
      );

      // "Show on Map" pins the status at wherever the device actually is
      // right now, not whatever stale location was last shared — capture it
      // at submit time rather than when the composer opened.
      if (draft.privacy == StatusPrivacy.showOnMap) {
        if (!await locationService.hasPermission()) {
          await locationService.requestPermission();
        }
        final position = await locationService.getCurrentPosition();
        if (position == null) {
          emit(StatusCreationError(draft, 'Location permission is required to show on map.'));
          return;
        }
        draft = draft.copyWith(longitude: position.longitude, latitude: position.latitude);
      }

      emit(StatusCreationUploading(draft));

      final result = await statusRepository.uploadStatus(draft);
      result.fold(
        (failure) => emit(StatusCreationError(draft, failure.message)),
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
