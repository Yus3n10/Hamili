import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamili/core/constants/app_constants.dart';
import 'package:hamili/features/auth/data/auth_repository.dart';
import 'package:hamili/features/auth/presentation/auth_providers.dart';
import 'package:hive/hive.dart';

enum _Server { up, offline, error, rejectsSession }

class _FakeApi implements HttpClientAdapter {
  _Server server = _Server.up;
  Map<String, Object?> me = _user(1, 'a@example.com');

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    switch (server) {
      case _Server.offline:
        throw DioException.connectionError(requestOptions: options, reason: 'offline');
      case _Server.error:
        return _json(503, {'detail': 'waking up'});
      case _Server.rejectsSession:
        return _json(401, {'detail': 'Invalid or expired token'});
      case _Server.up:
        if (options.path == '/auth/login') {
          return _json(200, {'access_token': 'access', 'refresh_token': 'refresh', 'token_type': 'bearer'});
        }
        return _json(200, me);
    }
  }

  @override
  void close({bool force = false}) {}
}

Map<String, Object?> _user(int id, String email) => {
      'id': id,
      'email': email,
      'preferred_name': 'User $id',
      'preferred_currency': 'PHP',
      'monthly_salary': null,
      'allowance': null,
      'financial_goal_text': null,
    };

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });

void main() {
  late Directory dir;
  late _FakeApi api;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('hamili_user_test');
    Hive.init(dir.path);
    await Hive.openBox<String>('app_settings');
    api = _FakeApi();
    FlutterSecureStorage.setMockInitialValues({
      AppConstants.accessTokenKey: 'access',
      AppConstants.refreshTokenKey: 'refresh',
    });
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  ProviderContainer openApp() {
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = api;
    final container = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(AuthRepository(dio: dio)),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  Future<int?> signedInUserId(ProviderContainer app) async => (await app.read(currentUserProvider.future))?.id;

  test('a signed-in user who opens the app offline stays signed in', () async {
    await signedInUserId(openApp());

    api.server = _Server.offline;

    expect(await signedInUserId(openApp()), 1);
  });

  test('a server error at startup keeps the user signed in', () async {
    await signedInUserId(openApp());

    api.server = _Server.error;

    expect(await signedInUserId(openApp()), 1);
  });

  test('a session the server rejects at startup goes to login', () async {
    await signedInUserId(openApp());

    api.server = _Server.rejectsSession;

    expect(await signedInUserId(openApp()), isNull);
  });

  test('an offline start never restores a user who logged out', () async {
    final app = openApp();
    await signedInUserId(app);
    await app.read(currentUserProvider.notifier).logout();

    FlutterSecureStorage.setMockInitialValues({
      AppConstants.accessTokenKey: 'stale-access',
      AppConstants.refreshTokenKey: 'stale-refresh',
    });
    api.server = _Server.offline;

    expect(await signedInUserId(openApp()), isNull);
  });

  test('an offline start restores the account that logged in last', () async {
    final app = openApp();
    await signedInUserId(app);
    await app.read(currentUserProvider.notifier).logout();

    api.me = _user(2, 'b@example.com');
    await app.read(currentUserProvider.notifier).login(email: 'b@example.com', password: 'pw-12345678');
    api.server = _Server.offline;

    expect(await signedInUserId(openApp()), 2);
  });
}
