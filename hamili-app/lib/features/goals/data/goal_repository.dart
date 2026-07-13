import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/network/api_client.dart';
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

  Future<AppSavingsGoal> create({required String title, required double targetAmount, DateTime? targetDate}) async {
    final response = await _dio.post('/goals', data: {
      'title': title,
      'target_amount': targetAmount,
      if (targetDate != null) 'target_date': targetDate.toIso8601String().split('T').first,
    });
    return AppSavingsGoal.fromJson(response.data);
  }

  Future<AppSavingsGoal> contribute(int id, double amount) async {
    final response = await _dio.post('/goals/$id/contribute', data: {'amount': amount});
    return AppSavingsGoal.fromJson(response.data);
  }

  Future<void> delete(int id) async {
    await _dio.delete('/goals/$id');
  }

  Future<void> clearCache() async {
    final box = await Hive.openBox<String>(_boxName);
    await box.clear();
  }
}
