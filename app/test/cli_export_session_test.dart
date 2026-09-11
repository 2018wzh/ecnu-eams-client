import 'dart:async';
import 'dart:convert';
import 'package:eams_core/eams_core.dart';
import 'package:ecnu_eams_client/providers/course_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response renewed() => http.Response(
  jsonEncode({
    'code': 0,
    'data': {'token': 'new-token'},
  }),
  200,
  headers: {'content-type': 'application/json'},
);

Future<CourseProvider> prepare(ApiService api) async {
  SharedPreferences.setMockInitialValues({});
  api.setAuthorization('old-token');
  api.setPortalSession(
    const PortalSession(session: 'session', gateway: 'gateway'),
  );
  final provider = CourseProvider(apiService: api);
  await provider.bindContext(1, 2, 3);
  provider.addRobTarget({
    'id': 10,
    'course': {'nameZh': 'A'},
  }, virtualCost: 0);
  addTearDown(() async {
    await provider.saveAutomationState();
    provider.dispose();
    api.close();
  });
  return provider;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'export rejects an expired portal session before creating configuration',
    () async {
      var requests = 0;
      final api = ApiService(
        client: MockClient((request) async {
          expect(request.url.path, '/portal-service/token/renew');
          requests++;
          return http.Response('', 200, headers: {'session-invalid': 'true'});
        }),
      );
      final provider = await prepare(api);
      await expectLater(
        provider.exportRobConfig(),
        throwsA(isA<ApiException>()),
      );
      expect(provider.isExporting, isFalse);
      expect(requests, 1);
      expect(await api.getAuthorization(), 'old-token');
    },
  );

  test(
    'export contains the renewed token after identity verification',
    () async {
      final requests = <String>[];
      final api = ApiService(
        client: MockClient((request) async {
          requests.add(request.url.path);
          if (request.url.path == '/portal-service/token/renew') {
            return renewed();
          }
          expect(request.method, 'GET');
          expect(request.headers['authorization'], 'new-token');
          return http.Response(
            jsonEncode({
              'result': 0,
              'data': [1],
            }),
            200,
          );
        }),
      );
      final provider = await prepare(api);
      final config = await provider.exportRobConfig();
      expect(config.token, 'new-token');
      expect(config.portalSession, isNotNull);
      expect(provider.isExporting, isFalse);
      expect(requests, [
        '/portal-service/token/renew',
        '/course-selection-api/api/v1/student/course-select/students',
      ]);
    },
  );

  test(
    'stop cancels export and prevents committing an in-flight renewal',
    () async {
      final sent = Completer<void>();
      final response = Completer<http.Response>();
      var requests = 0;
      final api = ApiService(
        client: MockClient((request) async {
          requests++;
          sent.complete();
          return response.future;
        }),
      );
      final provider = await prepare(api);
      final export = provider.exportRobConfig();
      final assertion = expectLater(export, throwsA(isA<OperationCancelled>()));
      await sent.future;
      await provider.stopAllAndWait();
      response.complete(renewed());
      await assertion;
      expect(requests, 1);
      expect(await api.getAuthorization(), 'old-token');
      expect(provider.isExporting, isFalse);
    },
  );
}
