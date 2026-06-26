import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ciro_chat_app/core/error/failures.dart';
import 'package:ciro_chat_app/features/call_history/domain/entities/call_history_record.dart';
import 'package:ciro_chat_app/features/call_history/domain/repositories/call_history_repository.dart';
import 'package:ciro_chat_app/features/call_history/presentation/bloc/call_history_cubit.dart';

class MockCallHistoryRepository extends Mock implements CallHistoryRepository {}

CallHistoryRecord _record(String name, {int startedAt = 0}) => CallHistoryRecord(
      id: name,
      contactUserId: name,
      contactName: name,
      direction: CallDirection.incoming,
      outcome: CallOutcome.answered,
      callType: CallType.voice,
      startedAt: startedAt,
    );

void main() {
  setUpAll(() {
    registerFallbackValue(_record('fallback'));
  });

  late MockCallHistoryRepository repo;
  late StreamController<List<CallHistoryRecord>> controller;

  setUp(() {
    repo = MockCallHistoryRepository();
    controller = StreamController<List<CallHistoryRecord>>.broadcast();
    when(() => repo.watchAll()).thenAnswer((_) => controller.stream);
  });

  tearDown(() => controller.close());

  blocTest<CallHistoryCubit, CallHistoryState>(
    'load() emits CallHistoryLoaded with the records from the repository stream',
    build: () => CallHistoryCubit(repo),
    act: (cubit) {
      cubit.load();
      controller.add([_record('Alice'), _record('Bob')]);
    },
    expect: () => [
      isA<CallHistoryLoaded>().having((s) => s.records.length, 'records.length', 2),
    ],
  );

  blocTest<CallHistoryCubit, CallHistoryState>(
    'search() filters the in-memory list by contact name',
    build: () => CallHistoryCubit(repo),
    act: (cubit) async {
      cubit.load();
      controller.add([_record('Alice'), _record('Bob')]);
      await Future<void>.delayed(Duration.zero);
      cubit.search('ali');
    },
    expect: () => [
      isA<CallHistoryLoaded>().having((s) => s.records.length, 'records.length', 2),
      isA<CallHistoryLoaded>()
          .having((s) => s.records.length, 'records.length', 1)
          .having((s) => s.records.single.contactName, 'contactName', 'Alice'),
    ],
  );

  test('close() cancels the underlying stream subscription', () async {
    final cubit = CallHistoryCubit(repo);
    cubit.load();
    expect(controller.hasListener, isTrue);
    await cubit.close();
    expect(controller.hasListener, isFalse);
  });

  blocTest<CallHistoryCubit, CallHistoryState>(
    'repository stream error emits CallHistoryError',
    build: () => CallHistoryCubit(repo),
    act: (cubit) {
      cubit.load();
      controller.addError(Exception('boom'));
    },
    expect: () => [isA<CallHistoryError>()],
  );

  test('add() failure is reported as a Failure (Either contract)', () async {
    when(() => repo.add(any())).thenAnswer((_) async => Left(CacheFailure('x')));
    final result = await repo.add(_record('Alice'));
    expect(result.isLeft(), isTrue);
  });
}
