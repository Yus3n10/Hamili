import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/offline_queue.dart';
import '../domain/transaction.dart';


class TransactionRepository {
  TransactionRepository({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  final Dio _dio;
  static const _boxName = 'transactions_cache';
  static const _cacheKey = 'all';

  Future<List<AppTransaction>> list({int? categoryId, String? search}) async {
    try {
      final response = await _dio.get('/transactions', queryParameters: {
        if (categoryId != null) 'category_id': categoryId,
        if (search != null && search.isNotEmpty) 'search': search,
      });
      final transactions = (response.data as List).map((json) => AppTransaction.fromJson(json)).toList();


      if (categoryId == null && (search == null || search.isEmpty)) {
        await _cacheTransactions(transactions);
      }
      return transactions;
    } catch (_) {
      final cached = await _readCache();
      var filtered = cached;
      if (categoryId != null) filtered = filtered.where((t) => t.categoryId == categoryId).toList();
      if (search != null && search.isNotEmpty) {
        filtered = filtered.where((t) => (t.note ?? '').toLowerCase().contains(search.toLowerCase())).toList();
      }
      return filtered;
    }
  }

  Future<AppTransaction> create({
    required int categoryId,
    required double amount,
    required String type,
    required DateTime transactionDate,
    String? note,
  }) async {
    final data = {
      'category_id': categoryId,
      'amount': amount,
      'type': type,
      'note': note,
      'transaction_date': transactionDate.toIso8601String().split('T').first,
    };
    try {
      final response = await _dio.post('/transactions', data: data);
      return AppTransaction.fromJson(response.data);
    } on DioException catch (e) {
      if (OfflineQueue.isConnectionError(e)) {
        await OfflineQueue.instance.enqueue(method: 'POST', path: '/transactions', data: data);
        throw const OfflineQueuedException();
      }
      rethrow;
    }
  }

  Future<AppTransaction> update(
    int id, {
    int? categoryId,
    double? amount,
    String? note,
    DateTime? transactionDate,
  }) async {
    final data = {
      if (categoryId != null) 'category_id': categoryId,
      if (amount != null) 'amount': amount,
      if (note != null) 'note': note,
      if (transactionDate != null) 'transaction_date': transactionDate.toIso8601String().split('T').first,
    };
    try {
      final response = await _dio.patch('/transactions/$id', data: data);
      return AppTransaction.fromJson(response.data);
    } on DioException catch (e) {
      if (OfflineQueue.isConnectionError(e)) {
        await OfflineQueue.instance.enqueue(method: 'PATCH', path: '/transactions/$id', data: data);
        throw const OfflineQueuedException();
      }
      rethrow;
    }
  }

  Future<void> delete(int id) async {
    try {
      await _dio.delete('/transactions/$id');
    } on DioException catch (e) {
      if (OfflineQueue.isConnectionError(e)) {
        await OfflineQueue.instance.enqueue(method: 'DELETE', path: '/transactions/$id');
        throw const OfflineQueuedException();
      }
      rethrow;
    }
  }


  Future<void> clearCache() async {
    final box = await Hive.openBox<String>(_boxName);
    await box.delete(_cacheKey);
  }

  Future<void> _cacheTransactions(List<AppTransaction> transactions) async {
    final box = await Hive.openBox<String>(_boxName);
    final encoded = jsonEncode(transactions.map((t) => t.toJson()).toList());
    await box.put(_cacheKey, encoded);
  }

  Future<List<AppTransaction>> _readCache() async {
    final box = await Hive.openBox<String>(_boxName);
    final raw = box.get(_cacheKey);
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List;
    return decoded.map((json) => AppTransaction.fromJson(json)).toList();
  }
}
