import 'package:ciro_chat_app/core/error/failures.dart';
import 'package:ciro_chat_app/features/status/domain/entities/ai_image_result.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_audience_contact.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_entity.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_reaction.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_viewer.dart';
import 'package:fpdart/fpdart.dart';

abstract class StatusRepository {
  Future<Either<Failure, List<StatusEntity>>> getRecentStatuses();
  Future<Either<Failure, List<StatusEntity>>> getViewedStatuses();
  /// All of the current user's active statuses, oldest first.
  Future<Either<Failure, List<StatusEntity>>> getMyStatuses();
  Future<Either<Failure, void>> markAsViewed(String statusId);
  Future<Either<Failure, void>> addStatus(StatusEntity status);
  Stream<StatusEntity> get statusStream;
  Future<Either<Failure, void>> purgeExpiredStatuses();

  // New methods for Creation Flow
  Future<Either<Failure, void>> uploadStatus(StatusEntity status);
  Future<Either<Failure, AIImageResult>> generateAIImage(String prompt);

  // 014-status-feature-integration: feed, viewers, audience, reactions/replies
  Future<Either<Failure, List<StatusEntity>>> getFeed();
  Future<Either<Failure, List<StatusViewer>>> getViewers(String statusId);
  Future<Either<Failure, List<StatusAudienceContact>>> getDefaultAudience();
  Future<Either<Failure, void>> react(String statusId, String reaction);
  Future<Either<Failure, void>> reply(String statusId, String message);

  /// Fired when someone views one of OUR statuses.
  Stream<({String statusId, StatusViewer viewer})> get statusViewerAddedStream;

  /// Fired when someone reacts to one of OUR statuses.
  Stream<({String statusId, StatusReaction reaction})> get statusReactedStream;
}
