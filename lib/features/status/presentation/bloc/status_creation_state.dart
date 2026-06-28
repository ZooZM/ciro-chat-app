import 'package:ciro_chat_app/features/status/domain/entities/status_entity.dart';
import 'package:equatable/equatable.dart';

abstract class StatusCreationState extends Equatable {
  const StatusCreationState();

  @override
  List<Object?> get props => [];
}

class StatusCreationIdle extends StatusCreationState {}

class StatusCreationComposing extends StatusCreationState {
  final StatusEntity draft;
  final bool isRecording;

  const StatusCreationComposing(this.draft, {this.isRecording = false});

  @override
  List<Object?> get props => [draft, isRecording];
}

class StatusCreationUploading extends StatusCreationState {
  final StatusEntity draft;

  const StatusCreationUploading(this.draft);

  @override
  List<Object?> get props => [draft];
}

class StatusCreationSuccess extends StatusCreationState {}

class StatusCreationError extends StatusCreationState {
  final StatusEntity draft;
  final String message;

  const StatusCreationError(this.draft, this.message);

  @override
  List<Object?> get props => [draft, message];
}
