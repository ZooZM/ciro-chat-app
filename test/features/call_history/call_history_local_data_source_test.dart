import 'package:ciro_chat_app/features/call_history/data/datasources/call_history_local_data_source.dart';
import 'package:ciro_chat_app/features/call_history/data/models/call_history_record_model.dart';
import 'package:ciro_chat_app/features/call_history/domain/entities/call_history_record.dart';
import 'package:ciro_chat_app/features/chat/data/datasources/chat_local_data_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MockChatLocalDataSource extends Mock implements ChatLocalDataSource {}

const _schema = '''
  CREATE TABLE IF NOT EXISTS call_history (
    id                TEXT PRIMARY KEY,
    contact_user_id   TEXT NOT NULL,
    contact_name      TEXT NOT NULL,
    avatar_url        TEXT,
    avatar_color_seed INTEGER NOT NULL DEFAULT 0,
    direction         TEXT NOT NULL,
    outcome           TEXT NOT NULL,
    call_type         TEXT NOT NULL,
    is_group          INTEGER NOT NULL DEFAULT 0,
    started_at        INTEGER NOT NULL,
    duration_seconds  INTEGER NOT NULL DEFAULT 0
  )
''';

CallHistoryRecordModel _record(String id, {int startedAt = 0, String contactName = 'Alice'}) =>
    CallHistoryRecordModel(
      id: id,
      contactUserId: id,
      contactName: contactName,
      direction: CallDirection.incoming,
      outcome: CallOutcome.answered,
      callType: CallType.voice,
      startedAt: startedAt,
    );

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  late Database db;
  late MockChatLocalDataSource chatLocalDataSource;
  late CallHistoryLocalDataSourceImpl dataSource;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute(_schema);
    chatLocalDataSource = MockChatLocalDataSource();
    when(() => chatLocalDataSource.database).thenReturn(db);
    dataSource = CallHistoryLocalDataSourceImpl(chatLocalDataSource);
  });

  tearDown(() async {
    await dataSource.dispose();
    await db.close();
  });

  test('add() then getAll() returns the inserted record sorted by started_at DESC', () async {
    await dataSource.add(_record('a', startedAt: 100));
    await dataSource.add(_record('b', startedAt: 200, contactName: 'Bob'));

    final all = await dataSource.getAll();
    expect(all.map((r) => r.id), ['b', 'a']);
  });

  test('add() is idempotent on id (INSERT OR REPLACE)', () async {
    await dataSource.add(_record('a', startedAt: 100, contactName: 'Alice'));
    await dataSource.add(_record('a', startedAt: 100, contactName: 'Alice Updated'));

    final all = await dataSource.getAll();
    expect(all.length, 1);
    expect(all.single.contactName, 'Alice Updated');
  });

  test('search() filters by contact name (case-insensitive substring)', () async {
    await dataSource.add(_record('a', contactName: 'Alice'));
    await dataSource.add(_record('b', contactName: 'Bob'));

    final results = await dataSource.search('ali');
    expect(results.map((r) => r.contactName), ['Alice']);
  });

  test('watchAll() emits the current snapshot, then a new snapshot after add()', () async {
    await dataSource.add(_record('a', contactName: 'Alice'));

    final emissions = <int>[];
    final sub = dataSource.watchAll().listen((records) => emissions.add(records.length));

    await Future<void>.delayed(Duration.zero);
    await dataSource.add(_record('b', contactName: 'Bob'));
    await Future<void>.delayed(Duration.zero);

    expect(emissions, [1, 2]);
    await sub.cancel();
  });
}
