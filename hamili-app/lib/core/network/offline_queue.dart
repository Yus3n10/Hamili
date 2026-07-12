import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Thrown by a repository when a write couldn't reach the server because
/// the device is offline, but was queued for replay. Callers treat this
/// as a "saved, will sync" outcome rather than a failure.
class OfflineQueuedException implements Exception {
  const OfflineQueuedException();
}

class QueuedOp {
  final String id;
  final String method;
  final String path;
  final Map<String, dynamic>? data;

  QueuedOp({required this.id, required this.method, required this.path, this.data});

  Map<String, dynamic> toJson() => {'id': id, 'method': method, 'path': path, 'data': data};

  factory QueuedOp.fromJson(Map<String, dynamic> j) => QueuedOp(
        id: j['id'] as String,
        method: j['method'] as String,
        path: j['path'] as String,
        data: (j['data'] as Map?)?.cast<String, dynamic>(),
      );
}

/// A durable, in-order queue of mutating requests that failed because the
/// device was offline. Persisted in Hive so pending writes survive an app
/// restart, and drained (replayed) the next time a request succeeds.
///
/// Scope note: currently wired into transaction writes (the primary write
/// path). Other features still require connectivity; extending them is a
/// matter of the same enqueue-on-connection-error pattern.
class OfflineQueue {
  OfflineQueue._();
  static final OfflineQueue instance = OfflineQueue._();

  static const _boxName = 'offline_queue_v1';
  static const _key = 'ops';

  /// Number of writes waiting to sync — drives the UI's offline banner.
  final ValueNotifier<int> pendingCount = ValueNotifier<int>(0);
  bool _flushing = false;

  Future<Box<String>> _box() => Hive.openBox<String>(_boxName);

  Future<List<QueuedOp>> _read() async {
    final box = await _box();
    final raw = box.get(_key);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((j) => QueuedOp.fromJson((j as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> _write(List<QueuedOp> ops) async {
    final box = await _box();
    await box.put(_key, jsonEncode(ops.map((o) => o.toJson()).toList()));
    pendingCount.value = ops.length;
  }

  /// Load the persisted pending count at startup.
  Future<void> init() async {
    pendingCount.value = (await _read()).length;
  }

  Future<void> enqueue({required String method, required String path, Map<String, dynamic>? data}) async {
    final ops = await _read();
    ops.add(QueuedOp(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      method: method,
      path: path,
      data: data,
    ));
    await _write(ops);
  }

  /// Replay queued ops in order. Stops at the first connection error (still
  /// offline) and keeps the rest; drops an op that fails with a real server
  /// error (e.g. 4xx) since retrying it would never succeed. Reentrancy is
  /// guarded so the success interceptor can call this freely.
  Future<void> flush(Dio dio) async {
    if (_flushing) return;
    _flushing = true;
    try {
      var ops = await _read();
      while (ops.isNotEmpty) {
        final op = ops.first;
        try {
          await dio.request(op.path, data: op.data, options: Options(method: op.method));
          ops = ops.sublist(1);
          await _write(ops);
        } on DioException catch (e) {
          if (isConnectionError(e)) break;
          ops = ops.sublist(1); // permanent failure — drop it and move on
          await _write(ops);
        }
      }
    } finally {
      _flushing = false;
    }
  }

  static bool isConnectionError(DioException e) {
    return e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        (e.type == DioExceptionType.unknown && e.response == null);
  }
}
