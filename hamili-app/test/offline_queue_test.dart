import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamili/core/network/offline_queue.dart';
import 'package:hive/hive.dart';

class _RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> sent = [];
  Future<void> Function()? duringRequest;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    sent.add(options);
    await duringRequest?.call();
    return ResponseBody.fromString('{}', 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  final queue = OfflineQueue.instance;
  late Directory dir;
  late Dio dio;
  late _RecordingAdapter adapter;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('hamili_queue_test');
    Hive.init(dir.path);
    adapter = _RecordingAdapter();
    dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter;
    await queue.init();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  Future<void> queueAsUser(int userId) async {
    await queue.beginSession(userId, restored: true);
    await queue.enqueue(method: 'POST', path: '/goals', data: {'title': 'A goal'});
  }

  test("A's queued writes are discarded when A logs out and B logs in", () async {
    await queueAsUser(1);

    await queue.endSession();
    await queue.beginSession(2, restored: false);
    await queue.flush(dio);

    expect(adapter.sent, isEmpty);
    expect(queue.pendingCount.value, 0);
  });

  test("A's queued writes are not sent under B when A's session expired without logout", () async {
    await queueAsUser(1);

    queue.suspend();
    await queue.beginSession(2, restored: false);
    await queue.flush(dio);

    expect(adapter.sent, isEmpty);
    expect(queue.pendingCount.value, 0);
  });

  test("A's queued writes are sent once A's own session is restored", () async {
    await queueAsUser(1);

    queue.suspend();
    await queue.beginSession(1, restored: true);
    await queue.flush(dio);

    expect(adapter.sent.map((o) => o.path), ['/goals']);
    expect(queue.pendingCount.value, 0);
  });

  test('logging out mid-flush does not bring the cleared writes back', () async {
    await queueAsUser(1);
    await queue.enqueue(method: 'POST', path: '/budgets', data: {'limit_amount': 100});
    adapter.duringRequest = () => queue.endSession();

    await queue.flush(dio);
    await queue.beginSession(2, restored: false);
    adapter.duringRequest = null;
    await queue.flush(dio);

    expect(adapter.sent.map((o) => o.path), ['/goals']);
    expect(queue.pendingCount.value, 0);
  });

  test('a write queued during a flush is not lost', () async {
    await queueAsUser(1);
    adapter.duringRequest = () async {
      adapter.duringRequest = null;
      await queue.enqueue(method: 'DELETE', path: '/goals/3');
    };

    await queue.flush(dio);

    expect(adapter.sent.map((o) => o.path), ['/goals', '/goals/3']);
    expect(queue.pendingCount.value, 0);
  });

  test('nothing is flushed while no session is active', () async {
    await queueAsUser(1);

    queue.suspend();
    await queue.flush(dio);

    expect(adapter.sent, isEmpty);
    expect(queue.pendingCount.value, 1);
  });

  group('writes queued before ownership tracking', () {
    Future<void> seedLegacyOp() async {
      final box = await Hive.openBox<String>('offline_queue_v1');
      await box.put('ops', jsonEncode([
        {'id': '1', 'method': 'POST', 'path': '/goals', 'data': null},
      ]));
      await queue.init();
    }

    test('are kept and sent when the stored session is restored', () async {
      await seedLegacyOp();

      await queue.beginSession(7, restored: true);
      await queue.flush(dio);

      expect(adapter.sent.map((o) => o.path), ['/goals']);
    });

    test('are discarded on a fresh login', () async {
      await seedLegacyOp();

      await queue.beginSession(7, restored: false);
      await queue.flush(dio);

      expect(adapter.sent, isEmpty);
      expect(queue.pendingCount.value, 0);
    });
  });
}
