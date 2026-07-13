import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/network/api_client.dart';
import '../domain/category.dart';


class CategoryRepository {
  CategoryRepository({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  final Dio _dio;
  static const _boxName = 'categories_cache';
  static const _cacheKey = 'all';

  Future<List<AppCategory>> getCategories({String? type}) async {
    try {
      final response = await _dio.get('/categories', queryParameters: type != null ? {'type': type} : null);
      final categories = (response.data as List).map((json) => AppCategory.fromJson(json)).toList();

      if (type == null) await _cacheCategories(categories);
      return categories;
    } catch (error) {
      final cached = await _readCache();


      if (cached.isEmpty) rethrow;

      if (type != null) return cached.where((c) => c.type == type).toList();
      return cached;
    }
  }

  Future<void> _cacheCategories(List<AppCategory> categories) async {
    final box = await Hive.openBox<String>(_boxName);
    final encoded = jsonEncode(categories
        .map((c) => {'id': c.id, 'name': c.name, 'type': c.type, 'icon': c.icon})
        .toList());
    await box.put(_cacheKey, encoded);
  }

  Future<List<AppCategory>> _readCache() async {
    final box = await Hive.openBox<String>(_boxName);
    final raw = box.get(_cacheKey);
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List;
    return decoded.map((json) => AppCategory.fromJson(json)).toList();
  }
}
