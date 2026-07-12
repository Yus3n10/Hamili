import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/app_constants.dart';
import 'offline_queue.dart';

/// Single Dio instance for the whole app. The interceptor attaches the
/// stored access token to every request automatically, so feature
/// repositories never handle auth headers themselves.
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
          // Any successful request proves we're back online — drain any
          // writes that were queued while offline (reentrancy-guarded).
          if (OfflineQueue.instance.pendingCount.value > 0) {
            OfflineQueue.instance.flush(_dio);
          }
          handler.next(response);
        },
        // Milestone 3+: onError -> attempt refresh-token flow on 401
        // before surfacing the error to the caller.
      ),
    );
  }

  static final ApiClient instance = ApiClient._internal();
  static const _storage = FlutterSecureStorage();

  late final Dio _dio;
  Dio get dio => _dio;
}
