import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/app_constants.dart';
import 'offline_queue.dart';


class ApiClient {
  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: AppConstants.accessTokenKey);
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onResponse: (response, handler) {


          if (OfflineQueue.instance.pendingCount.value > 0) {
            OfflineQueue.instance.flush(_dio);
          }
          handler.next(response);
        },


      ),
    );
  }

  static final ApiClient instance = ApiClient._internal();
  static const _storage = FlutterSecureStorage();

  late final Dio _dio;
  Dio get dio => _dio;
}
