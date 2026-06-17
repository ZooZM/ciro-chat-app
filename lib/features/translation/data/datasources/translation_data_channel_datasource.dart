import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../domain/entities/caption.dart';
import '../models/caption_model.dart';

/// Owns ingestion of `topic: "translation"` LiveKit data-channel packets —
/// the presentation layer never sees raw `DataReceivedEvent`s
/// (Constitution I, research.md §2).
///
/// Uses `room.events.listen()` rather than `room.createListener().on<>()`:
/// in livekit_client 2.8.x the typed-listener delegate misses events when the
/// subscription is created after `room.connect()` completes, whereas the
/// underlying `EventsStream` (a broadcast `Stream<RoomEvent>`) always delivers
/// to late subscribers.
@injectable
class TranslationDataChannelDataSource {
  // room.events.listen() returns CancelListenFunc, not StreamSubscription.
  CancelListenFunc? _roomEventsSub;
  StreamController<Caption>? _controller;

  /// Subscribes to [room.events], filters `DataReceivedEvent`s on
  /// `topic == 'translation'`, parses them via [CaptionModel.fromJson], and
  /// emits [Caption] entities. Malformed packets are dropped with a single
  /// [debugPrint] (Constitution VII).
  Stream<Caption> attach(Room room) {
    detach();

    final controller = StreamController<Caption>.broadcast();
    _controller = controller;

    _roomEventsSub = room.events.listen((event) {
      if (event is! DataReceivedEvent) return;

      debugPrint(
        '[TranslationDSrc] DataReceivedEvent — topic: "${event.topic}", bytes: ${event.data.length}',
      );
      if (event.topic != 'translation') return;

      String rawText = '';
      Object? decoded;
      try {
        rawText = utf8.decode(event.data);
        debugPrint('[TranslationDSrc] Raw JSON: $rawText');
        decoded = jsonDecode(rawText);
      } catch (e) {
        debugPrint('[TranslationDSrc] Failed to decode packet: $e');
        return;
      }

      if (decoded is! Map) {
        debugPrint('[TranslationDSrc] Dropped non-Map packet');
        return;
      }

      final model = CaptionModel.fromJson(Map<String, dynamic>.from(decoded));
      if (model == null) {
        debugPrint('[TranslationDSrc] Dropped malformed caption — raw: $rawText');
        return;
      }

      debugPrint(
        '[TranslationDSrc] Parsed caption → speakerId=${model.speakerId}'
        ' type=${model.type} targetLanguage=${model.targetLanguage}'
        ' text="${model.text}"',
      );
      controller.add(model.toEntity());
    });

    return controller.stream;
  }

  /// Cancels the room-events subscription and closes the caption stream.
  /// Safe to call multiple times.
  void detach() {
    _roomEventsSub?.call();
    _roomEventsSub = null;
    _controller?.close();
    _controller = null;
  }

  void dispose() => detach();
}
