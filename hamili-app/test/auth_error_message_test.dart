import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamili/features/auth/presentation/auth_error_message.dart';

DioException _response(int status, [Object? data]) {
  final options = RequestOptions(path: '/auth/login');
  return DioException.badResponse(
    statusCode: status,
    requestOptions: options,
    response: Response(requestOptions: options, statusCode: status, data: data),
  );
}

void main() {
  final offline = DioException.connectionError(requestOptions: RequestOptions(path: '/auth/login'), reason: 'offline');
  final timeout = DioException(requestOptions: RequestOptions(path: '/auth/login'), type: DioExceptionType.receiveTimeout);

  test('wrong password on login says so', () {
    expect(authErrorMessage(_response(401)), "That email and password don't match.");
  });

  test('a login lockout passes the server reason through', () {
    expect(
      authErrorMessage(_response(429, {'detail': 'Too many failed login attempts. Please try again in a few minutes.'})),
      'Too many failed login attempts. Please try again in a few minutes.',
    );
  });

  test('a taken email on register says so', () {
    expect(authErrorMessage(_response(400, {'detail': 'Email already registered'}), registering: true),
        'That email already has an account. Try signing in.');
  });

  test('offline and timeouts are not blamed on the password', () {
    for (final e in [offline, timeout]) {
      expect(authErrorMessage(e), "Can't reach Hamili right now. Check your connection and try again.");
    }
  });

  test('server errors ask to retry', () {
    expect(authErrorMessage(_response(503)), 'Hamili is having trouble right now. Try again in a minute.');
  });

  test('anything else falls back to a generic message', () {
    expect(authErrorMessage(StateError('x')), 'Something went wrong. Try again.');
  });
}
