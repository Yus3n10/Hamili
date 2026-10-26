import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../domain/admin_models.dart';

class AdminRepository {
  AdminRepository({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  final Dio _dio;

  Future<AdminOverview> overview() async {
    final response = await _dio.get('/admin/overview');
    return AdminOverview.fromJson(response.data);
  }

  Future<AdminTesterPage> testers({String search = '', String sort = 'last_active', int page = 1}) async {
    final response = await _dio.get('/admin/testers', queryParameters: {
      if (search.isNotEmpty) 'search': search,
      'sort': sort,
      'page': page,
      'page_size': 100,
    });
    return AdminTesterPage.fromJson(response.data);
  }

  Future<List<AdminAccessEntry>> accessLog({int page = 1}) async {
    final response = await _dio.get('/admin/access-log', queryParameters: {'page': page});
    return (response.data['items'] as List)
        .map((e) => AdminAccessEntry.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }
}
