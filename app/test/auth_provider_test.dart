import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:async';
import 'dart:convert';
import 'package:ecnu_eams_client/providers/auth_provider.dart';
import 'package:eams_core/eams_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(
    () => FlutterSecureStorage.setMockInitialValues({
      'authorization': 'test-token',
    }),
  );
  test(
    'legacy plaintext tokens are removed without restoring a session',
    () async {
      SharedPreferences.setMockInitialValues({'authorization': 'legacy-token'});
      FlutterSecureStorage.setMockInitialValues({});
      final api = ApiService(
        client: MockClient(
          (_) async => throw StateError('Legacy credentials must not be used'),
        ),
      );
      final auth = AuthProvider(apiService: api);
      await auth.initialize();
      expect(auth.isAuthenticated, isFalse);
      expect(
        (await SharedPreferences.getInstance()).containsKey('authorization'),
        isFalse,
      );
      expect(
        await const FlutterSecureStorage().read(key: 'authorization'),
        isNull,
      );
      expect(auth.errorMessage, isNull);
      auth.dispose();
      api.close();
    },
  );
  test('authentication is committed only after student validation', () async {
    SharedPreferences.setMockInitialValues({});
    final gate = Completer<void>();
    final api = ApiService(
      client: MockClient((r) async {
        if (r.url.path.endsWith('students')) await gate.future;
        return http.Response(
          jsonEncode({
            'result': 0,
            'data': r.url.path.endsWith('students') ? [1] : [],
          }),
          200,
        );
      }),
    );
    final auth = AuthProvider(apiService: api);
    final login = auth.setAuthorization('token');
    await Future<void>.delayed(Duration.zero);
    expect(auth.isAuthenticated, isFalse);
    gate.complete();
    await login;
    expect(auth.isAuthenticated, isTrue);
    expect(auth.studentID, '1');
    final exported = ClientConfig.fromBase64((await auth.exportClientConfig()).toBase64(),
    );
    expect(exported.studentId, 1);
    expect(exported.token, 'token');
    expect(exported.turnId, isNull);
    await auth.logout();
    expect(auth.isAuthenticated, isFalse);
    await expectLater(auth.exportClientConfig(), throwsStateError);
    expect(
      await const FlutterSecureStorage().read(key: 'authorization'),
      isNull,
    );
    api.close();
    auth.dispose();
  });
  test('invalid credentials never open authenticated UI', () async {
    SharedPreferences.setMockInitialValues({});
    final api = ApiService(
      client: MockClient((_) async => http.Response('', 401)),
    );
    final auth = AuthProvider(apiService: api);
    await expectLater(
      auth.setAuthorization('bad'),
      throwsA(isA<ApiException>()),
    );
    expect(auth.isAuthenticated, isFalse);
    expect(auth.studentID, isNull);
    api.close();
    auth.dispose();
  });
  test(
    'browser session is saved securely and manual login clears it',
    () async {
      const storage = FlutterSecureStorage();
      final api = ApiService(
        client: MockClient(
          (r) async => http.Response(
            jsonEncode({
              'result': 0,
              'data': r.url.path.endsWith('students') ? [1] : [],
            }),
            200,
          ),
        ),
      );
      final auth = AuthProvider(apiService: api);
      const session = PortalSession(
        session: 'session-secret',
        gateway: 'gateway-secret',
      );
      await auth.setAuthorization('token', portalSession: session);
      expect(
        jsonDecode((await storage.read(key: 'portalSession'))!),
        session.toJson(),
      );
      expect((await auth.exportClientConfig()).portalSession, isNull);
      await auth.setAuthorization('manual-token');
      expect(await storage.read(key: 'portalSession'), isNull);
      await auth.setAuthorization('token', portalSession: session);
      await auth.logout();
      expect(await storage.read(key: 'portalSession'), isNull);
      auth.dispose();
      api.close();
    },
  );
  test(
    'transient startup failure preserves credentials for a later retry',
    () async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({'authorization': 'token'});
      final api = ApiService(
        client: MockClient((_) async => http.Response('', 503)),
      );
      final auth = AuthProvider(apiService: api);
      await auth.initialize();
      expect(auth.isInitializing, isFalse);
      expect(auth.isAuthenticated, isFalse);
      expect(
        await const FlutterSecureStorage().read(key: 'authorization'),
        'token',
      );
      api.close();
      auth.dispose();
    },
  );
}
