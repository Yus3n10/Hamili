import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/network/api_client.dart';
import '../domain/recurring_item.dart';

/// Mirrors TransactionRepository: successful list fetches overwrite a
/// Hive box; on fetch failure we fall back to the cache ONLY when it
/// actually holds data, so a real error is never masked as an empty
/// state. Writes require the network (Milestone 7 adds a queue).
class RecurringRepository {
  RecurringRepository({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  final Dio _dio;
  static const _boxName = 'recurring_cache';
  static const _cacheKey = 'all';

  Future<List<RecurringItem>> list() async {
    try {
      final response = await _dio.get('/recurring');
      final items = (response.data as List).map((json) => RecurringItem.fromJson(json)).toList();
      await _cache(items);
      return items;
    } catch (_) {
      final cached = await _readCache();
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  Future<RecurringItem> create({
    required String type,
    required String name,
    required double amount,
    required int categoryId,
    required String frequency,
    required DateTime nextDueDate,
    bool active = true,
  }) async {
    final response = await _dio.post('/recurring', data: {
      'type': type,
      'name': name,
      'amount': amount,
      'category_id': categoryId,
      'frequency': frequency,
      'next_due_date': nextDueDate.toIso8601String().split('T').first,
      'active': active,
    });
    return RecurringItem.fromJson(response.data);
  }

  Future<RecurringItem> update(
    int id, {
    String? name,
    double? amount,
    int? categoryId,
    String? frequency,
    DateTime? nextDueDate,
    bool? active,
  }) async {
    final response = await _dio.patch('/recurring/$id', data: {
      if (name != null) 'name': name,
      if (amount != null) 'amount': amount,
      if (categoryId != null) 'category_id': categoryId,
      if (frequency != null) 'frequency': frequency,
      if (nextDueDate != null) 'next_due_date': nextDueDate.toIso8601String().split('T').first,
      if (active != null) 'active': active,
    });
    return RecurringItem.fromJson(response.data);
  }

  Future<void> delete(int id) async {
    await _dio.delete('/recurring/$id');
  }

  /// Promotes any due items server-side; returns how many transactions
  /// were created so the UI can confirm the outcome.
  Future<int> runDue() async {
    final response = await _dio.post('/recurring/run-due');
    return (response.data['promoted'] as num).toInt();
  }

  Future<void> clearCache() async {
    final box = await Hive.openBox<String>(_boxName);
    await box.delete(_cacheKey);
  }

  Future<void> _cache(List<RecurringItem> items) async {
    final box = await Hive.openBox<String>(_boxName);
    await box.put(_cacheKey, jsonEncode(items.map((i) => i.toJson()).toList()));
  }

  Future<List<RecurringItem>> _readCache() async {
    final box = await Hive.openBox<String>(_boxName);
    final raw = box.get(_cacheKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).map((json) => RecurringItem.fromJson(json)).toList();
  }
}
