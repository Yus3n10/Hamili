import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';


class OfflineQueuedException implements Exception {
  const OfflineQueuedException();
}

class QueuedOp {
  final String id;
  final String method;
  final String path;
  final Map<String, dynamic>? data;
  final int? userId;

  QueuedOp({required this.id, required this.method, required this.path, this.data, this.userId});

  QueuedOp ownedBy(int owner) => QueuedOp(id: id, method: method, path: path, data: data, userId: owner);

  Map<String, dynamic> toJson() => {'id': id, 'method': method, 'path': path, 'data': data, 'userId': userId};

  factory QueuedOp.fromJson(Map<String, dynamic> j) => QueuedOp(
        id: j['id'] as String,
        method: j['method'] as String,
        path: j['path'] as String,
        data: (j['data'] as Map?)?.cast<String, dynamic>(),
        userId: j['userId'] as int?,
      );
}


class OfflineQueue {
  OfflineQueue._();
  static final OfflineQueue instance = OfflineQueue._();

  static const _boxName = 'offline_queue_v1';
  static const _key = 'ops';


  final ValueNotifier<int> pendingCount = ValueNotifier<int>(0);
  bool _flushing = false;

  // Queued writes replay under whichever token is stored when they flush, so
  // each op is tagged with its owner and only the active owner's ops are sent.
  int? _activeUserId;

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


  Future<void> init() async {
    pendingCount.value = (await _read()).length;
  }

  // `restored` means the stored session was resumed on app start, so untagged
  // ops written before ownership tracking existed belong to this user. On a
  // fresh login their owner is unknown and they are discarded.
  Future<void> beginSession(int userId, {required bool restored}) async {
    final kept = <QueuedOp>[];
    for (final op in await _read()) {
      if (op.userId == userId) {
        kept.add(op);
      } else if (op.userId == null && restored) {
        kept.add(op.ownedBy(userId));
      }
    }
    await _write(kept);
    _activeUserId = userId;
  }

  Future<void> endSession() async {
    _activeUserId = null;
    await _write([]);
  }

  void suspend() {
    _activeUserId = null;
  }

  Future<void> enqueue({required String method, required String path, Map<String, dynamic>? data}) async {
    final ops = await _read();
    ops.add(QueuedOp(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      method: method,
      path: path,
      data: data,
      userId: _activeUserId,
    ));
    await _write(ops);
  }

  Future<T> guardWrite<T>(
    Future<T> Function() request, {
    required String method,
    required String path,
    Map<String, dynamic>? data,
  }) async {
    try {
      return await request();
    } on DioException catch (e) {
      if (isConnectionError(e)) {
        await enqueue(method: method, path: path, data: data);
        throw const OfflineQueuedException();
      }
      rethrow;
    }
  }


  Future<void> flush(Dio dio) async {
    final owner = _activeUserId;
    if (_flushing || owner == null) return;
    _flushing = true;
    try {
      // Re-read storage each pass so a logout or a newly queued write made
      // while a request is in flight is never overwritten by a stale copy.
      while (_activeUserId == owner) {
        final pending = (await _read()).where((o) => o.userId == owner);
        if (pending.isEmpty) break;
        final op = pending.first;
        try {
          await dio.request(op.path, data: op.data, options: Options(method: op.method));
        } on DioException catch (e) {
          if (isConnectionError(e)) break;
        }
        await _remove(op.id);
      }
    } finally {
      _flushing = false;
    }
  }

  Future<void> _remove(String id) async {
    final ops = await _read();
    ops.removeWhere((o) => o.id == id);
    await _write(ops);
  }

  static bool isConnectionError(DioException e) {
    return e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        (e.type == DioExceptionType.unknown && e.response == null);
  }
}
