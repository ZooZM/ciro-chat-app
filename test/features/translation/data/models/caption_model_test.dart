import 'package:flutter_test/flutter_test.dart';
import 'package:ciro_chat_app/features/translation/data/models/caption_model.dart';
import 'package:ciro_chat_app/features/translation/domain/entities/caption.dart';

void main() {
  group('CaptionModel.fromJson', () {
    test('parses a valid interim payload', () {
      final json = {
        'v': 1,
        'type': 'interim',
        'speakerId': 'user-1',
        'sourceLanguage': 'en',
        'targetLanguage': 'ar',
        'text': 'Hello',
        'segmentId': 'seg-1',
        'seq': 1,
        'ts': 1000,
      };

      final model = CaptionModel.fromJson(json);

      expect(model, isNotNull);
      expect(model!.type, 'interim');
      expect(model.speakerId, 'user-1');
      expect(model.sourceLanguage, 'en');
      expect(model.targetLanguage, 'ar');
      expect(model.text, 'Hello');
      expect(model.segmentId, 'seg-1');
      expect(model.seq, 1);
      expect(model.ts, 1000);

      final entity = model.toEntity();
      expect(entity.type, CaptionType.interim);
    });

    test('parses a valid final payload and maps type to final_', () {
      final json = {
        'v': 1,
        'type': 'final',
        'speakerId': 'user-1',
        'sourceLanguage': 'en',
        'targetLanguage': 'ar',
        'text': 'Hello world.',
        'segmentId': 'seg-1',
        'seq': 3,
        'ts': 2000,
      };

      final model = CaptionModel.fromJson(json);

      expect(model, isNotNull);
      expect(model!.type, 'final');
      final entity = model.toEntity();
      expect(entity.type, CaptionType.final_);
    });

    test('returns null when speakerId is missing', () {
      final json = {
        'v': 1,
        'type': 'interim',
        'sourceLanguage': 'en',
        'targetLanguage': 'ar',
        'text': 'Hello',
        'segmentId': 'seg-1',
        'seq': 1,
        'ts': 1000,
      };

      expect(CaptionModel.fromJson(json), isNull);
    });

    test('returns null when segmentId is missing', () {
      final json = {
        'v': 1,
        'type': 'interim',
        'speakerId': 'user-1',
        'sourceLanguage': 'en',
        'targetLanguage': 'ar',
        'text': 'Hello',
        'seq': 1,
        'ts': 1000,
      };

      expect(CaptionModel.fromJson(json), isNull);
    });

    test('returns null when type is invalid', () {
      final json = {
        'v': 1,
        'type': 'partial',
        'speakerId': 'user-1',
        'sourceLanguage': 'en',
        'targetLanguage': 'ar',
        'text': 'Hello',
        'segmentId': 'seg-1',
        'seq': 1,
        'ts': 1000,
      };

      expect(CaptionModel.fromJson(json), isNull);
    });

    test('defaults missing seq/ts to 0', () {
      final json = {
        'v': 1,
        'type': 'interim',
        'speakerId': 'user-1',
        'sourceLanguage': 'en',
        'targetLanguage': 'ar',
        'text': '',
        'segmentId': 'seg-1',
      };

      final model = CaptionModel.fromJson(json);

      expect(model, isNotNull);
      expect(model!.seq, 0);
      expect(model.ts, 0);
      expect(model.text, '');
    });
  });
}
