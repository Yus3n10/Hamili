import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamili/core/network/offline_queue.dart';
import 'package:hamili/features/transactions/data/transaction_repository.dart';
import 'package:hamili/features/transactions/presentation/transaction_providers.dart';
import 'package:hive/hive.dart';

class _FakeServer implements HttpClientAdapter {
  bool online = false;
  final List<RequestOptions> writes = [];
  final List<Map<String, dynamic>> stored = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (!online) throw DioException.connectionError(requestOptions: options, reason: 'offline');
    if (options.method == 'GET') return _json(200, stored);
    writes.add(options);
    if (options.path.startsWith('/transactions/-')) return _json(404, {'detail': 'Transaction not found'});
    if (options.method == 'DELETE') return ResponseBody.fromString('', 204);
    final row = {'id': 501, 'type': 'expense', ...Map<String, dynamic>.from(options.data as Map)};
    if (options.method == 'POST') stored.add(row);
    return _json(options.method == 'POST' ? 201 : 200, row);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });

void main() {
  late Directory dir;
  late _FakeServer server;
  late Dio dio;
  late ProviderContainer app;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('hamili_txn_test');
    Hive.init(dir.path);
    server = _FakeServer();
    dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = server;
    await OfflineQueue.instance.init();
    await OfflineQueue.instance.beginSession(1, restored: false);
    app = ProviderContainer(overrides: [
      transactionRepositoryProvider.overrideWithValue(TransactionRepository(dio: dio)),
    ]);
    await app.read(transactionsProvider.future);
  });

  tearDown(() async {
    app.dispose();
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  TransactionsNotifier transactions() => app.read(transactionsProvider.notifier);

  Future<int> addWhileOffline() async {
    await expectLater(
      transactions().addTransaction(categoryId: 3, amount: 50, type: 'expense', transactionDate: DateTime(2026, 10, 25)),
      throwsA(isA<OfflineQueuedException>()),
    );
    return app.read(transactionsProvider).value!.single.id;
  }

  Future<void> sync() async {
    server.online = true;
    await OfflineQueue.instance.flush(dio);
  }

  List<String> sentWrites() => [for (final o in server.writes) '${o.method} ${o.path}'];

  test('editing a transaction added offline syncs the edited values', () async {
    final tempId = await addWhileOffline();

    await expectLater(transactions().editTransaction(tempId, amount: 75), throwsA(isA<OfflineQueuedException>()));
    await sync();

    expect(sentWrites(), ['POST /transactions']);
    expect((server.writes.single.data as Map)['amount'], 75);
    expect(OfflineQueue.instance.pendingCount.value, 0);
  });

  test('deleting a transaction added offline syncs nothing', () async {
    final tempId = await addWhileOffline();

    await transactions().deleteTransaction(tempId);
    await sync();

    expect(sentWrites(), isEmpty);
    expect(OfflineQueue.instance.pendingCount.value, 0);
  });

  test('editing it after reconnecting but before sync still applies the edit', () async {
    final tempId = await addWhileOffline();
    server.online = true;

    await expectLater(transactions().editTransaction(tempId, note: 'lunch'), throwsA(isA<OfflineQueuedException>()));
    await OfflineQueue.instance.flush(dio);

    expect(sentWrites(), ['POST /transactions']);
    expect((server.writes.single.data as Map)['note'], 'lunch');
  });

  test('deleting it after reconnecting but before sync keeps it deleted', () async {
    final tempId = await addWhileOffline();
    server.online = true;

    await transactions().deleteTransaction(tempId);
    await OfflineQueue.instance.flush(dio);

    expect(sentWrites(), isEmpty);
  });

  test('the screen shows the synced transaction, not the temporary one', () async {
    final tempId = await addWhileOffline();
    await expectLater(transactions().editTransaction(tempId, amount: 75), throwsA(isA<OfflineQueuedException>()));

    await sync();
    await pumpEventQueue();
    final shown = await app.read(transactionsProvider.future);

    expect([for (final t in shown) (t.id, t.amount)], [(501, 75.0)]);
  });
}
