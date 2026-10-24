import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamili/core/constants/app_constants.dart';
import 'package:hamili/core/network/api_client.dart';

typedef _Handler = ResponseBody Function(RequestOptions options);

class _RoutingAdapter implements HttpClientAdapter {
  _RoutingAdapter(this.onRefresh);

  final _Handler onRefresh;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (options.path == '/auth/refresh') return onRefresh(options);
    final authorized = options.headers['Authorization'] == 'Bearer new-access';
    return _json(authorized ? 200 : 401, authorized ? {'ok': true} : {'detail': 'expired'});
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });

void main() {
  const storage = FlutterSecureStorage();
  final dio = ApiClient.instance.dio;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      AppConstants.accessTokenKey: 'expired-access',
      AppConstants.refreshTokenKey: 'refresh-1',
    });
  });

  Future<Map<String, String?>> savedTokens() async => {
        'access': await storage.read(key: AppConstants.accessTokenKey),
        'refresh': await storage.read(key: AppConstants.refreshTokenKey),
      };

  test('a refresh that cannot reach the server keeps the saved login', () async {
    dio.httpClientAdapter = _RoutingAdapter(
      (o) => throw DioException.connectionError(requestOptions: o, reason: 'offline'),
    );

    await expectLater(dio.get('/protected'), throwsA(isA<DioException>()));

    expect(await savedTokens(), {'access': 'expired-access', 'refresh': 'refresh-1'});
  });

  test('a refresh the server fails with a 5xx keeps the saved login', () async {
    dio.httpClientAdapter = _RoutingAdapter((o) => _json(503, {'detail': 'waking up'}));

    await expectLater(dio.get('/protected'), throwsA(isA<DioException>()));

    expect(await savedTokens(), {'access': 'expired-access', 'refresh': 'refresh-1'});
  });

  test('a refresh the server rejects clears the saved login', () async {
    dio.httpClientAdapter = _RoutingAdapter((o) => _json(401, {'detail': 'Invalid or expired refresh token'}));

    await expectLater(dio.get('/protected'), throwsA(isA<DioException>()));

    expect(await savedTokens(), {'access': null, 'refresh': null});
  });

  test('a successful refresh retries the request with the new token', () async {
    dio.httpClientAdapter = _RoutingAdapter(
      (o) => _json(200, {'access_token': 'new-access', 'refresh_token': 'refresh-2'}),
    );

    final response = await dio.get('/protected');

    expect(response.statusCode, 200);
    expect(await savedTokens(), {'access': 'new-access', 'refresh': 'refresh-2'});
  });
}
