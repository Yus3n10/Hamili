import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../domain/goal.dart';

class GoalRepository {
  GoalRepository({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  final Dio _dio;

  Future<List<AppSavingsGoal>> list() async {
    final response = await _dio.get('/goals');
    return (response.data as List).map((json) => AppSavingsGoal.fromJson(json)).toList();
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
}
