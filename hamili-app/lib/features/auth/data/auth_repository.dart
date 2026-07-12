import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../domain/app_user.dart';

/// Only class in the app that knows about HTTP paths for auth. Providers
/// and widgets call these methods and never touch Dio directly.
class AuthRepository {
  AuthRepository({Dio? dio, FlutterSecureStorage? storage})
      : _dio = dio ?? ApiClient.instance.dio,
        _storage = storage ?? const FlutterSecureStorage();

  final Dio _dio;
  final FlutterSecureStorage _storage;

  Future<void> register({
    required String email,
    required String password,
    required String preferredName,
  }) async {
    await _dio.post('/auth/register', data: {
      'email': email,
      'password': password,
      'preferred_name': preferredName,
    });
  }

  Future<void> login({required String email, required String password}) async {
    final response = await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });

    await _storage.write(key: AppConstants.accessTokenKey, value: response.data['access_token']);
    await _storage.write(key: AppConstants.refreshTokenKey, value: response.data['refresh_token']);
  }

  Future<AppUser> getCurrentUser() async {
    final response = await _dio.get('/auth/me');
    return AppUser.fromJson(response.data);
  }

  Future<AppUser> updateProfile({
    String? preferredName,
    String? preferredCurrency,
    String? financialGoalText,
  }) async {
    final response = await _dio.patch('/auth/me', data: {
      if (preferredName != null) 'preferred_name': preferredName,
      if (preferredCurrency != null) 'preferred_currency': preferredCurrency,
      if (financialGoalText != null) 'financial_goal_text': financialGoalText,
    });
    return AppUser.fromJson(response.data);
  }

  Future<bool> hasStoredSession() async {
    final token = await _storage.read(key: AppConstants.accessTokenKey);
    return token != null;
  }

  Future<void> logout() async {
    await clearStoredSession();
  }

  /// Removes any persisted tokens. Called on logout, and also at app
  /// startup so a session never silently resumes across app launches
  /// (see main.dart) — the user must re-authenticate every time.
  Future<void> clearStoredSession() async {
    await _storage.delete(key: AppConstants.accessTokenKey);
    await _storage.delete(key: AppConstants.refreshTokenKey);
  }
}
