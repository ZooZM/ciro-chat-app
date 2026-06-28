import 'dart:convert';

import 'package:ciro_chat_app/core/error/failures.dart';
import 'package:ciro_chat_app/core/network/socket_service.dart';
import 'package:ciro_chat_app/core/utils/url_utils.dart';
import 'package:ciro_chat_app/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:ciro_chat_app/features/chat/data/datasources/chat_local_data_source.dart';
import 'package:ciro_chat_app/features/chat/domain/entities/message.dart';
import 'package:ciro_chat_app/features/status/data/datasources/status_local_data_source.dart';
import 'package:ciro_chat_app/features/status/data/datasources/status_remote_data_source.dart';
import 'package:ciro_chat_app/features/status/data/models/status_audience_contact_model.dart';
import 'package:ciro_chat_app/features/status/data/models/status_model.dart';
import 'package:ciro_chat_app/features/status/data/models/status_reaction_model.dart';
import 'package:ciro_chat_app/features/status/data/models/status_viewer_model.dart';
import 'package:ciro_chat_app/features/status/domain/entities/ai_image_result.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_audience_contact.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_entity.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_reaction.dart';
import 'package:ciro_chat_app/features/status/domain/entities/status_viewer.dart';
import 'package:ciro_chat_app/features/status/domain/repositories/status_repository.dart';
import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// T052: SharedPreferences key caching the user's default status audience
/// (data-model.md §5).
const _kDefaultAudienceCacheKey = 'status_default_audience';

@LazySingleton(as: StatusRepository)
class StatusRepositoryImpl implements StatusRepository {
  final StatusLocalDataSource localDataSource;
  final StatusRemoteDataSource remoteDataSource;
  final AuthLocalDataSource authLocalDataSource;
  final SocketService socketService;
  final ChatLocalDataSource chatLocalDataSource;
  final _uuid = const Uuid();

  StatusRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
    required this.authLocalDataSource,
    required this.socketService,
    required this.chatLocalDataSource,
  }) {
    // T028: server confirmed a previously-pending status — promote to synced
    remoteDataSource.onStatusUploaded.listen((data) {
      final clientStatusId = data['clientStatusId']?.toString();
      if (clientStatusId == null || clientStatusId.isEmpty) return;
      localDataSource.updateSyncStatus(
        clientStatusId,
        'synced',
        newId: data['id']?.toString(),
      );
    });

    // T027: replay queued uploads whenever the socket (re)connects
    socketService.isConnectedNotifier.addListener(() {
      if (socketService.isConnectedNotifier.value) {
        _replayPendingStatuses();
      }
    });
  }

  Future<void> _replayPendingStatuses() async {
    final pending = await localDataSource.getPendingStatuses();
    for (final status in pending) {
      try {
        final ack = await remoteDataSource.uploadStatus(status);
        if (ack != null) {
          await localDataSource.updateSyncStatus(
            status.clientStatusId,
            'synced',
            newId: ack['id']?.toString(),
          );
        }
      } catch (_) {
        // Still offline or failed — leave 'pending' for the next reconnect.
      }
    }
  }

  @override
  Future<Either<Failure, List<StatusEntity>>> getRecentStatuses() async {
    try {
      try {
        final feed = await remoteDataSource.getFeed();
        for (final status in feed) {
          await localDataSource.cacheStatus(status);
        }
      } catch (_) {
        // Offline or request failed — fall back to whatever is cached locally.
      }
      final statuses = await localDataSource.getStatuses(isViewed: false);
      final phoneToName = await _getContactPhoneToName();
      return Right(statuses.map((s) => _resolveContactName(s, phoneToName)).toList());
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<StatusEntity>>> getViewedStatuses() async {
    try {
      final statuses = await localDataSource.getStatuses(isViewed: true);
      final phoneToName = await _getContactPhoneToName();
      return Right(statuses.map((s) => _resolveContactName(s, phoneToName)).toList());
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  /// Builds a lookup map from the locally cached contacts table.
  /// Keys: contact's backend user ID + contact's phone number.
  /// Values: the name the device user saved for that contact.
  Future<Map<String, String>> _getContactPhoneToName() async {
    try {
      final contacts = await chatLocalDataSource.watchContacts().first;
      final map = <String, String>{};
      for (final c in contacts) {
        if (c.name.isEmpty || c.name == 'Unknown') continue;
        // Match by backend user ID (most reliable — used when authorId is a userId)
        if (c.id.isNotEmpty) map[c.id] = c.name;
        // Match by phone number (fallback — used when authorName is a phone number)
        if (c.phoneNumber.isNotEmpty) map[c.phoneNumber] = c.name;
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  /// Returns [status] with [authorName] replaced by the device contact name
  /// when the author can be matched in the contact lookup by userId or phone.
  StatusEntity _resolveContactName(
    StatusEntity status,
    Map<String, String> lookup,
  ) {
    if (status.isMine) return status;
    // Prefer authorId lookup (backend userId → saved contact name)
    final resolved = lookup[status.authorId] ?? lookup[status.authorName];
    if (resolved != null && resolved.isNotEmpty) {
      return status.copyWith(authorName: resolved);
    }
    return status;
  }

  @override
  Future<Either<Failure, List<StatusEntity>>> getMyStatuses() async {
    try {
      final statuses = await localDataSource.getMyStatuses();
      if (statuses.isEmpty) return const Right([]);

      final lookup = await _getContactPhoneToName();

      // Fetch current viewers + reactions from the server for each uploaded
      // status so they survive cubit reloads (SQLite has no viewers/reactions
      // columns — both only exist in memory otherwise).
      final enriched = await Future.wait(
        statuses.map((status) async {
          if (status.syncStatus != 'synced') return status;
          try {
            final results = await Future.wait([
              remoteDataSource.getViewers(status.id),
              remoteDataSource.getReactions(status.id),
            ]);
            final rawViewers = results[0] as List<StatusViewerModel>;
            final rawReactions = results[1] as List<StatusReactionModel>;

            final resolvedViewers = rawViewers.map((v) {
              final name = lookup[v.userId] ?? v.name;
              return StatusViewerModel(
                userId: v.userId,
                name: name.isEmpty ? v.name : name,
                avatarUrl: v.avatarUrl,
                viewedAt: v.viewedAt,
              );
            }).toList();

            return status.copyWith(
              viewers: resolvedViewers,
              reactions: rawReactions,
            );
          } catch (_) {
            return status;
          }
        }),
      );

      return Right(enriched);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> markAsViewed(String statusId) async {
    try {
      await localDataSource.markAsViewed(statusId);
      await remoteDataSource.notifyViewed(statusId);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> addStatus(StatusEntity status) async {
    return uploadStatus(status);
  }

  @override
  Future<Either<Failure, void>> uploadStatus(StatusEntity status) async {
    final clientStatusId = status.clientStatusId.isNotEmpty ? status.clientStatusId : _uuid.v4();
    try {
      final currentUserId = await authLocalDataSource.getUserId() ?? '';
      final statusModel = StatusModel(
        id: clientStatusId,
        authorName: status.authorName,
        authorAvatar: status.authorAvatar,
        timestamp: status.timestamp,
        expiresAt: status.expiresAt,
        isViewed: status.isViewed,
        isMine: true,
        contentType: status.contentType,
        textContent: status.textContent,
        mediaUrl: status.mediaUrl,
        backgroundColor: status.backgroundColor,
        fontStyle: status.fontStyle,
        musicTrackId: status.musicTrackId,
        caption: status.caption,
        privacy: status.privacy,
        clientStatusId: clientStatusId,
        authorId: currentUserId,
        audience: status.audience,
        syncStatus: 'pending',
        longitude: status.longitude,
        latitude: status.latitude,
      );
      // Optimistic local insert (FR-002/FR-016/Constitution III)
      await localDataSource.cacheStatus(statusModel);

      try {
        final ack = await remoteDataSource.uploadStatus(statusModel);
        if (ack != null) {
          // Media uploads are confirmed synchronously via the REST response.
          // The ack's mediaUrl points at the server-hosted file - swap out
          // the local device file path used for the optimistic insert so
          // image widgets don't try to load it as a network URL.
          final rawMediaUrl = ack['mediaUrl'] as String?;
          await localDataSource.updateSyncStatus(
            clientStatusId,
            'synced',
            newId: ack['id']?.toString(),
            mediaUrl: (rawMediaUrl == null || rawMediaUrl.isEmpty)
                ? null
                : UrlUtils.resolveMediaUrl(rawMediaUrl),
          );
        }
        // Text statuses stay 'pending' until the `statusUploaded` socket ACK (T028).
        return const Right(null);
      } on DioException catch (e) {
        if (e.response != null) {
          // Non-recoverable rejection (e.g. 4xx) — surface a retry option.
          await localDataSource.updateSyncStatus(clientStatusId, 'error');
          return Left(ServerFailure(e.message ?? 'Status upload failed'));
        }
        // No connectivity — leave as 'pending' for offline-queue replay (T027).
        return const Right(null);
      } catch (e) {
        await localDataSource.updateSyncStatus(clientStatusId, 'error');
        return Left(ServerFailure(e.toString()));
      }
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> react(String statusId, String reaction) async {
    try {
      await remoteDataSource.react(statusId, reaction);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> reply(String statusId, String message) async {
    try {
      final messageJson = await remoteDataSource.reply(statusId, message);
      await chatLocalDataSource.saveMessage(Message.fromNetworkMap(messageJson));
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<StatusEntity>>> getFeed() async {
    try {
      final statuses = await remoteDataSource.getFeed();
      return Right(statuses);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<StatusViewer>>> getViewers(String statusId) async {
    try {
      final viewers = await remoteDataSource.getViewers(statusId);
      return Right(viewers);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<StatusAudienceContact>>> getDefaultAudience() async {
    try {
      final contacts = await remoteDataSource.getDefaultAudience();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kDefaultAudienceCacheKey,
        jsonEncode(contacts.map((c) => {
              'userId': c.userId,
              'name': c.name,
              'phoneNumber': c.phoneNumber,
              'avatarUrl': c.avatarUrl,
            }).toList()),
      );
      return Right(contacts);
    } catch (e) {
      final cached = await _getCachedDefaultAudience();
      if (cached != null) return Right(cached);
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<List<StatusAudienceContactModel>?> _getCachedDefaultAudience() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_kDefaultAudienceCacheKey);
    if (cached == null) return null;
    try {
      return (jsonDecode(cached) as List<dynamic>)
          .map((e) => StatusAudienceContactModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Either<Failure, AIImageResult>> generateAIImage(String prompt) async {
    try {
      final result = await remoteDataSource.generateAIImage(prompt);
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Stream<StatusEntity> get statusStream =>
      remoteDataSource.onStatusReceived.asyncMap((model) async {
        localDataSource.cacheStatus(model);
        final phoneToName = await _getContactPhoneToName();
        return _resolveContactName(model, phoneToName);
      });

  @override
  Stream<({String statusId, StatusViewer viewer})> get statusViewerAddedStream =>
      remoteDataSource.onStatusViewerAdded.asyncMap((event) async {
        final lookup = await _getContactPhoneToName();
        final resolvedName = lookup[event.viewer.userId] ?? event.viewer.name;
        if (resolvedName == event.viewer.name) return event;
        return (
          statusId: event.statusId,
          viewer: StatusViewerModel(
            userId: event.viewer.userId,
            name: resolvedName,
            avatarUrl: event.viewer.avatarUrl,
            viewedAt: event.viewer.viewedAt,
          ),
        );
      });

  @override
  Stream<({String statusId, StatusReaction reaction})> get statusReactedStream =>
      remoteDataSource.onStatusReacted;

  @override
  Future<Either<Failure, void>> purgeExpiredStatuses() async {
    try {
      await localDataSource.deleteExpiredStatuses();
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }
}
