import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/app_constants.dart';
import 'offline_queue.dart';

enum _RefreshResult { refreshed, rejected, unavailable }


class ApiClient {
  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.apiBaseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
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
        onError: (error, handler) async {
          if (await _shouldRefresh(error)) {
            final result = await _refreshToken();
            if (result == _RefreshResult.refreshed) {
              try {
                handler.resolve(await _retry(error.requestOptions));
                return;
              } catch (_) {}
            } else if (result == _RefreshResult.rejected) {
              await _clearSession();
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  static final ApiClient instance = ApiClient._internal();
  static const _storage = FlutterSecureStorage();

  late final Dio _dio;
  Dio get dio => _dio;

  bool _refreshing = false;
  Completer<_RefreshResult>? _refreshWaiter;

  bool _isAuthPath(String path) =>
      path.contains('/auth/login') ||
      path.contains('/auth/register') ||
      path.contains('/auth/refresh');

  Future<bool> _shouldRefresh(DioException error) async {
    if (error.response?.statusCode != 401) return false;
    if (_isAuthPath(error.requestOptions.path)) return false;
    if (error.requestOptions.extra['retried'] == true) return false;
    return (await _storage.read(key: AppConstants.refreshTokenKey)) != null;
  }

  // Only a server that answers and refuses the refresh token ends the session.
  // Offline, timeouts and 5xx (e.g. a free-tier cold start) keep the saved
  // login so the next request can try again.
  Future<_RefreshResult> _refreshToken() async {
    if (_refreshing) return _refreshWaiter!.future;
    _refreshing = true;
    final waiter = _refreshWaiter = Completer<_RefreshResult>();
    var result = _RefreshResult.unavailable;
    try {
      final refreshToken = await _storage.read(key: AppConstants.refreshTokenKey);
      if (refreshToken == null) {
        result = _RefreshResult.rejected;
        return result;
      }
      final refreshDio = Dio(
        BaseOptions(
          baseUrl: AppConstants.apiBaseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
        ),
      )..httpClientAdapter = _dio.httpClientAdapter;
      final response = await refreshDio.post('/auth/refresh', data: {'refresh_token': refreshToken});
      await _storage.write(key: AppConstants.accessTokenKey, value: response.data['access_token']);
      await _storage.write(key: AppConstants.refreshTokenKey, value: response.data['refresh_token']);
      result = _RefreshResult.refreshed;
      return result;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status != null && status >= 400 && status < 500) result = _RefreshResult.rejected;
      return result;
    } catch (_) {
      return result;
    } finally {
      waiter.complete(result);
      _refreshing = false;
    }
  }

  Future<Response<dynamic>> _retry(RequestOptions options) {
    options.extra['retried'] = true;
    return _dio.fetch(options);
  }

  Future<void> _clearSession() async {
    OfflineQueue.instance.suspend();
    await _storage.delete(key: AppConstants.accessTokenKey);
    await _storage.delete(key: AppConstants.refreshTokenKey);
  }
}
