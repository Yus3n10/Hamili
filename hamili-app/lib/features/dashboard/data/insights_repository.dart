import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../domain/ai_insight.dart';


class InsightsRepository {
  InsightsRepository({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  final Dio _dio;

  Future<List<AiInsight>> get() async {
    final response = await _dio.get('/insights');
    return (response.data as List).map((j) => AiInsight.fromJson(j)).toList();
  }

  Future<List<AiInsight>> refresh() async {
    final response = await _dio.post('/insights/refresh');
    return (response.data as List).map((j) => AiInsight.fromJson(j)).toList();
  }

  Future<void> dismiss(int id) async {
    await _dio.patch('/insights/$id/dismiss');
  }
}
