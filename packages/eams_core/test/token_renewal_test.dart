import 'dart:async';
import 'dart:convert';
import 'package:eams_core/eams_core.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'api_service_test.dart' show reply;
import 'automation_runner_test.dart' show config, School;

const session = PortalSession(
  session: 'session-secret',
  gateway: 'gateway-secret',
);
http.Response renewed() => http.Response(
  jsonEncode({
    'code': 0,
    'data': {'token': 'new-token'},
  }),
  200,
  headers: {'content-type': 'application/json'},
);

void main() {
  for (final invalidSession in [true, false]) {
    test(
      'empty 200 is expired only with explicit portal header: $invalidSession',
      () async {
        var requests = 0;
        final api =
            ApiService(
                client: MockClient((_) async {
                  requests++;
                  return http.Response(
                    '',
                    200,
                    headers: {if (invalidSession) 'session-invalid': 'true'},
                  );
                }),
              )
              ..setAuthorization('old-token')
              ..setPortalSession(session);
        addTearDown(api.close);
        await expectLater(
          api.keepAlive(1),
          throwsA(
            isA<ApiException>()
                .having((e) => e.authExpired, 'authExpired', invalidSession)
                .having(
                  (e) => e.message,
                  'diagnostic',
                  contains(invalidSession ? 'Session-Invalid: true' : '0 字节'),
                ),
          ),
        );
        expect(requests, 1);
        expect(await api.getAuthorization(), 'old-token');
      },
    );
  }
  test(
    'server failure preserves HTTP status instead of reporting expiry',
    () async {
      final api =
          ApiService(
              client: MockClient((_) async => http.Response('SECRET', 503)),
            )
            ..setAuthorization('old-token')
            ..setPortalSession(session);
      addTearDown(api.close);
      await expectLater(
        api.keepAlive(1),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 503)
              .having((e) => e.authExpired, 'authExpired', false)
              .having((e) => e.message, 'message', isNot(contains('SECRET'))),
        ),
      );
    },
  );
  test('quoted cookie values are valid and missing cookies are identified', () {
    final quoted = PortalSession.fromJson({
      'SESSION': '"session-value"',
      'cookie': 'gateway',
    });
    expect(quoted.cookieHeader, 'SESSION="session-value"; cookie=gateway');
    expect(
      () => PortalSession.fromJson({'SESSION': 'session'}),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'missing name',
          contains('cookie'),
        ),
      ),
    );
  });
  test(
    'renews with scoped cookies and uses the replacement for later requests',
    () async {
      final paths = <String>[];
      final api =
          ApiService(
              client: MockClient((request) async {
                paths.add(request.url.path);
                expect(request.url.host, 'byyt.ecnu.edu.cn');
                if (request.url.path == '/portal-service/token/renew') {
                  expect(request.method, 'POST');
                  expect(request.followRedirects, isFalse);
                  expect(request.headers['cookie'], session.cookieHeader);
                  expect(jsonDecode(request.body), {'token': 'old-token'});
                  return renewed();
                }
                expect(request.headers['cookie'], isNull);
                expect(request.headers['authorization'], 'new-token');
                return reply([1]);
              }),
            )
            ..setAuthorization('old-token')
            ..setPortalSession(session);
      addTearDown(api.close);
      expect(await api.keepAlive(1), isTrue);
      expect(await api.getAuthorization(), 'new-token');
      await api.getStudentID();
      expect(paths.length, 3);
    },
  );

  for (final bad in [
    http.Response('', 302),
    http.Response('', 200),
    http.Response(
      '{SECRET',
      200,
      headers: {'content-type': 'application/json'},
    ),
    http.Response(
      '{"code":1,"msg":"session-secret"}',
      200,
      headers: {'content-type': 'application/json'},
    ),
  ]) {
    test(
      'rejects malformed or expired portal response without replacing credentials ${bad.statusCode} ${bad.body.length}',
      () async {
        final api = ApiService(client: MockClient((_) async => bad))
          ..setAuthorization('old-token')
          ..setPortalSession(session);
        addTearDown(api.close);
        try {
          await api.keepAlive(1);
          fail('Expected renewal failure');
        } catch (error) {
          expect(error.toString(), isNot(contains('SECRET')));
          expect(error.toString(), isNot(contains('session-secret')));
        }
        expect(await api.getAuthorization(), 'old-token');
      },
    );
  }

  test(
    'replacement identity must match before credential persistence',
    () async {
      var saved = false;
      final api =
          ApiService(
              client: MockClient(
                (r) async =>
                    r.url.path.endsWith('/renew') ? renewed() : reply([99]),
              ),
              onAuthorizationRenewed: (_, _) async {
                saved = true;
              },
            )
            ..setAuthorization('old-token')
            ..setPortalSession(session);
      addTearDown(api.close);
      await expectLater(api.keepAlive(1), throwsStateError);
      expect(saved, isFalse);
      expect(await api.getAuthorization(), 'old-token');
    },
  );

  test(
    'provider-backed credentials are updated and cache is cleared',
    () async {
      var stored = 'old-token';
      final api =
          ApiService(
              client: MockClient(
                (r) async =>
                    r.url.path.endsWith('/renew') ? renewed() : reply([1]),
              ),
              authorizationProvider: () async => stored,
              onAuthorizationRenewed: (previous, next) async {
                expect(previous, stored);
                stored = next;
              },
            )
            ..setAuthorization('old-token')
            ..setPortalSession(session);
      addTearDown(api.close);
      await api.keepAlive(1);
      expect(stored, 'new-token');
      stored = 'later-login';
      expect(await api.getAuthorization(), 'later-login');
    },
  );

  test(
    'cancelled renewal never verifies or commits returned credentials',
    () async {
      final sent = Completer<void>();
      final gate = Completer<http.Response>();
      final cancellation = CancellationToken();
      var calls = 0;
      final api =
          ApiService(
              client: MockClient((_) async {
                calls++;
                sent.complete();
                return gate.future;
              }),
            )
            ..setAuthorization('old-token')
            ..setPortalSession(session);
      addTearDown(api.close);
      final result = api.keepAlive(1, cancellation: cancellation);
      final checked = expectLater(result, throwsA(isA<OperationCancelled>()));
      await sent.future;
      cancellation.cancel();
      gate.complete(renewed());
      await checked;
      expect(calls, 1);
      expect(await api.getAuthorization(), 'old-token');
    },
  );

  test('concurrent scheduler renewals share one request', () async {
    var renewals = 0;
    final gate = Completer<void>();
    final api =
        ApiService(
            client: MockClient((r) async {
              if (r.url.path.endsWith('/renew')) {
                renewals++;
                await gate.future;
                return renewed();
              }
              return reply([1]);
            }),
          )
          ..setAuthorization('old-token')
          ..setPortalSession(session);
    addTearDown(api.close);
    final first = api.keepAlive(1);
    final second = api.keepAlive(1);
    await Future<void>.delayed(Duration.zero);
    expect(renewals, 1);
    gate.complete();
    await Future.wait([first, second]);
  });

  test(
    'configuration carries renewal credentials and rejects header injection',
    () {
      final json = config().toJson()..['portalSession'] = session.toJson();
      final encoded = AutomationConfig.fromJson(json).toBase64();
      expect(
        AutomationConfig.fromBase64(encoded).portalSession!.toJson(),
        session.toJson(),
      );
      expect(
        ClientConfig.fromBase64(encoded).portalSession!.toJson(),
        session.toJson(),
      );
      for (final value in ['bad;cookie', 'bad\r\nHeader: x', 'bad\u0000']) {
        expect(
          () => PortalSession.fromJson({'SESSION': value, 'cookie': 'ok'}),
          throwsFormatException,
        );
      }
      expect(session.toString(), isNot(contains('session-secret')));
    },
  );

  test('renewal waits for an in-flight selection transaction', () async {
    final school = School();
    final predicateSent = Completer<void>();
    final allowPredicate = Completer<void>();
    var renewals = 0;
    final api =
        ApiService(
            client: MockClient((request) async {
              if (request.url.path.endsWith('/add-predicate')) {
                predicateSent.complete();
                await allowPredicate.future;
              }
              if (request.url.path.endsWith('/renew')) {
                expect(school.writes, [3]);
                renewals++;
                return renewed();
              }
              return school.handle(request);
            }),
          )
          ..setAuthorization('old-token')
          ..setPortalSession(session);
    addTearDown(api.close);
    final selection = api.addCourse(1, 2, 3, 0);
    await predicateSent.future;
    final renewal = api.keepAlive(1);
    await Future<void>.delayed(Duration.zero);
    expect(renewals, 0);
    allowPredicate.complete();
    expect((await selection).success, isTrue);
    await renewal;
    expect(renewals, 1);
  });

  test(
    'renewal persistence failure stops automation before course writes',
    () async {
      final school = School();
      final api =
          ApiService(
              client: MockClient(
                (r) async => r.url.path.endsWith('/renew')
                    ? renewed()
                    : school.handle(r),
              ),
              onAuthorizationRenewed: (_, _) async =>
                  throw StateError('storage failed'),
            )
            ..setAuthorization('old-token')
            ..setPortalSession(session);
      addTearDown(api.close);
      final runner = AutomationRunner(
        api: api,
        config: config(),
        onUpdate: (_) async {},
      );
      await expectLater(runner.run(), throwsStateError);
      expect(school.writes, isEmpty);
      expect(await api.getAuthorization(), 'old-token');
    },
  );
}
