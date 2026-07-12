import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../domain/budget.dart';

class BudgetRepository {
  BudgetRepository({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  final Dio _dio;

  Future<List<AppBudget>> list({int? month, int? year}) async {
    final response = await _dio.get('/budgets', queryParameters: {
      if (month != null) 'month': month,
      if (year != null) 'year': year,
    });
    return (response.data as List).map((json) => AppBudget.fromJson(json)).toList();
  }

  /// POST /budgets is an upsert on the backend — safe to call whether or
  /// not a budget already exists for this category/month/year.
  Future<AppBudget> setBudget({
    required int categoryId,
    required int month,
    required int year,
    required double limitAmount,
  }) async {
    final response = await _dio.post('/budgets', data: {
      'category_id': categoryId,
      'month': month,
      'year': year,
      'limit_amount': limitAmount,
    });
    return AppBudget.fromJson(response.data);
  }

  Future<void> delete(int id) async {
    await _dio.delete('/budgets/$id');
  }
}
