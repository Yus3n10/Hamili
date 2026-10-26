import 'package:dio/dio.dart';

import '../../../core/network/offline_queue.dart';

// Maps a login or register failure to what actually went wrong, so an
// offline phone or a waking server is never reported as a bad password.
String authErrorMessage(Object error, {bool registering = false}) {
  if (error is! DioException) return 'Something went wrong. Try again.';
  if (OfflineQueue.isConnectionError(error)) {
    return "Can't reach Hamili right now. Check your connection and try again.";
  }

  final status = error.response?.statusCode ?? 0;
  final data = error.response?.data;
  final detail = data is Map && data['detail'] is String ? data['detail'] as String : null;

  if (status >= 500) return 'Hamili is having trouble right now. Try again in a minute.';
  if (status == 429) return detail ?? 'Too many attempts. Try again in a few minutes.';
  if (status == 401) return "That email and password don't match.";
  if (registering && status == 400) return 'That email already has an account. Try signing in.';
  return detail ?? 'Something went wrong. Try again.';
}
