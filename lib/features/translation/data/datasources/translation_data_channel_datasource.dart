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
@injectable
class TranslationDataChannelDataSource {
  EventsListener<RoomEvent>? _listener;
  StreamController<Caption>? _controller;

  /// Creates a dedicated [Room.createListener] for [room], filters
  /// `DataReceivedEvent`s on `topic == 'translation'`, parses them via
  /// [CaptionModel.fromJson], and emits [Caption] entities. Malformed
  /// packets are dropped with a single [debugPrint] (Constitution VII).
  Stream<Caption> attach(Room room) {
    detach();

    final controller = StreamController<Caption>.broadcast();
    _controller = controller;

    final listener = room.createListener();
    _listener = listener;

    listener.on<DataReceivedEvent>((event) {
      debugPrint('[TranslationDSrc] DataReceivedEvent — topic: "${event.topic}", bytes: ${event.data.length}');
      if (event.topic != 'translation') return;

      String rawText = '';
      Object? decoded;
      try {
        rawText = utf8.decode(event.data);
        debugPrint('[TranslationDSrc] Raw JSON: $rawText');
        decoded = jsonDecode(rawText);
      } catch (e) {
        debugPrint('[TranslationDataChannelDataSource] Failed to decode packet: $e');
        return;
      }

      if (decoded is! Map) {
        debugPrint('[TranslationDataChannelDataSource] Dropped non-Map packet');
        return;
      }

      final model = CaptionModel.fromJson(Map<String, dynamic>.from(decoded));
      if (model == null) {
        debugPrint('[TranslationDataChannelDataSource] Dropped malformed caption — raw: $rawText');
        return;
      }

      debugPrint('[TranslationDSrc] Parsed caption → speakerId=${model.speakerId} type=${model.type} targetLanguage=${model.targetLanguage} text="${model.text}"');
      controller.add(model.toEntity());
    });

    return controller.stream;
  }

  /// Cancels the [EventsListener] and closes the stream. Safe to call
  /// multiple times.
  void detach() {
    _listener?.dispose();
    _listener = null;
    _controller?.close();
    _controller = null;
  }

  void dispose() => detach();
}
