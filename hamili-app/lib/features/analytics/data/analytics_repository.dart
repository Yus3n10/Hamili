import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../domain/analytics_models.dart';

/// Analytics are online, server-computed views — no Hive cache (unlike
/// transactions). A failed fetch surfaces as an error to the UI.
class AnalyticsRepository {
  AnalyticsRepository({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  final Dio _dio;

  Future<AnalyticsSummary> summary({int? month, int? year}) async {
    final response = await _dio.get('/analytics/summary', queryParameters: {
      if (month != null) 'month': month,
      if (year != null) 'year': year,
    });
    return AnalyticsSummary.fromJson(response.data);
  }

  Future<List<CategoryBreakdown>> byCategory({required int month, required int year, String type = 'expense'}) async {
    final response = await _dio.get('/analytics/by-category', queryParameters: {
      'type': type,
      'month': month,
      'year': year,
    });
    return (response.data as List).map((j) => CategoryBreakdown.fromJson(j)).toList();
  }

  Future<List<TrendPoint>> trend({required int month, required int year, int months = 6}) async {
    final response = await _dio.get('/analytics/trend', queryParameters: {
      'month': month,
      'year': year,
      'months': months,
    });
    return (response.data as List).map((j) => TrendPoint.fromJson(j)).toList();
  }
}
