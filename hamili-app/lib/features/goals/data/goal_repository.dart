import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/offline_queue.dart';
import '../domain/goal.dart';

class GoalRepository {
  GoalRepository({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  final Dio _dio;
  static const _boxName = 'goals_cache';
  static const _cacheKey = 'all';

  Future<List<AppSavingsGoal>?> cached() async {
    final box = await Hive.openBox<String>(_boxName);
    final raw = box.get(_cacheKey);
    if (raw == null) return null;
    return (jsonDecode(raw) as List).map((json) => AppSavingsGoal.fromJson(json)).toList();
  }

  Future<List<AppSavingsGoal>> list() async {
    try {
      final response = await _dio.get('/goals');
      final box = await Hive.openBox<String>(_boxName);
      await box.put(_cacheKey, jsonEncode(response.data));
      return (response.data as List).map((json) => AppSavingsGoal.fromJson(json)).toList();
    } catch (_) {
      final fallback = await cached();
      if (fallback != null) return fallback;
      rethrow;
    }
  }

  Future<AppSavingsGoal> create({required String title, required double targetAmount, DateTime? targetDate}) {
    final data = {
      'title': title,
      'target_amount': targetAmount,
      if (targetDate != null) 'target_date': targetDate.toIso8601String().split('T').first,
    };
    return OfflineQueue.instance.guardWrite(
      () async => AppSavingsGoal.fromJson((await _dio.post('/goals', data: data)).data),
      method: 'POST',
      path: '/goals',
      data: data,
    );
  }

  Future<AppSavingsGoal> contribute(int id, double amount) {
    final data = {'amount': amount};
    return OfflineQueue.instance.guardWrite(
      () async => AppSavingsGoal.fromJson((await _dio.post('/goals/$id/contribute', data: data)).data),
      method: 'POST',
      path: '/goals/$id/contribute',
      data: data,
    );
  }

  Future<void> delete(int id) async {
    await OfflineQueue.instance.guardWrite(
      () => _dio.delete('/goals/$id'),
      method: 'DELETE',
      path: '/goals/$id',
    );
  }

  Future<void> clearCache() async {
    final box = await Hive.openBox<String>(_boxName);
    await box.clear();
  }
}
