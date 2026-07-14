import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/offline_queue.dart';
import '../domain/budget.dart';

class BudgetRepository {
  BudgetRepository({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  final Dio _dio;
  static const _boxName = 'budgets_cache';

  String _key(int? month, int? year) => '${month ?? 0}-${year ?? 0}';

  Future<List<AppBudget>?> cached({int? month, int? year}) async {
    final box = await Hive.openBox<String>(_boxName);
    final raw = box.get(_key(month, year));
    if (raw == null) return null;
    return (jsonDecode(raw) as List).map((json) => AppBudget.fromJson(json)).toList();
  }

  Future<List<AppBudget>> list({int? month, int? year}) async {
    try {
      final response = await _dio.get('/budgets', queryParameters: {
        if (month != null) 'month': month,
        if (year != null) 'year': year,
      });
      final box = await Hive.openBox<String>(_boxName);
      await box.put(_key(month, year), jsonEncode(response.data));
      return (response.data as List).map((json) => AppBudget.fromJson(json)).toList();
    } catch (_) {
      final fallback = await cached(month: month, year: year);
      if (fallback != null) return fallback;
      rethrow;
    }
  }

  Future<AppBudget> setBudget({
    required int categoryId,
    required int month,
    required int year,
    required double limitAmount,
  }) {
    final data = {
      'category_id': categoryId,
      'month': month,
      'year': year,
      'limit_amount': limitAmount,
    };
    return OfflineQueue.instance.guardWrite(
      () async => AppBudget.fromJson((await _dio.post('/budgets', data: data)).data),
      method: 'POST',
      path: '/budgets',
      data: data,
    );
  }

  Future<void> delete(int id) async {
    await OfflineQueue.instance.guardWrite(
      () => _dio.delete('/budgets/$id'),
      method: 'DELETE',
      path: '/budgets/$id',
    );
  }

  Future<void> clearCache() async {
    final box = await Hive.openBox<String>(_boxName);
    await box.clear();
  }
}
