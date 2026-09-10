import 'dart:async';
import 'dart:convert';
import 'package:eams_core/eams_core.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

http.Response reply(dynamic data, {int status = 200}) =>
    http.Response(jsonEncode({'result': 0, 'data': data}), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  test('429 exposes Retry-After for bounded retry scheduling', () async {
    final api = ApiService(
        client: MockClient((_) async =>
            http.Response('', 429, headers: {'retry-after': '30'})))
      ..setAuthorization('token');
    final result = await api.addCourse(1, 2, 3, 0);
    expect(result.outcome, ActionOutcome.retryable);
    expect(result.retryAfter, const Duration(seconds: 30));
    api.close();
  });

  test('HTTP-date Retry-After is supported', () async {
    final api = ApiService(
        client: MockClient((_) async => http.Response('', 429,
            headers: {'retry-after': 'Tue, 01 Jan 2030 00:00:00 GMT'})))
      ..setAuthorization('token');
    await expectLater(
        api.getCountInfo(3),
        throwsA(isA<ApiException>().having(
            (e) => e.retryAfter! > Duration.zero, 'future retry', isTrue)));
    api.close();
  });

  test('add verifies predicate, polls result and reconciles selected lessons',
      () async {
    final paths = <String>[];
    final responses = [
      reply('p'),
      reply(null),
      reply({'success': true}),
      reply('r'),
      reply({
        'success': true,
        'result': {'3': null}
      }),
      reply([
        {'id': 3}
      ])
    ];
    final api = ApiService(client: MockClient((r) async {
      paths.add(r.url.path);
      return responses.removeAt(0);
    }))
      ..setAuthorization('token');
    final result = await api.addCourse(1, 2, 3, 0);
    expect(result.success, isTrue);
    expect(result.requestId, 'r');
    expect(result.attempts, 3);
    expect(paths.last, endsWith('/selected-lessons/2/1'));
    api.close();
  });

  test('cancellation after predicate prevents submission', () async {
    final token = CancellationToken();
    final paths = <String>[];
    final api = ApiService(client: MockClient((r) async {
      paths.add(r.url.path);
      if (r.url.path.endsWith('add-predicate')) return reply('p');
      token.cancel();
      return reply({'success': true});
    }))
      ..setAuthorization('token');
    final result = await api.addCourse(1, 2, 3, 0, cancellation: token);
    expect(result.outcome, ActionOutcome.cancelled);
    expect(paths.any((p) => p.endsWith('add-request')), isFalse);
    api.close();
  });

  test('stopping after a write still reconciles it without another write',
      () async {
    final token = CancellationToken();
    var writes = 0;
    final api = ApiService(client: MockClient((r) async {
      if (r.url.path.endsWith('add-predicate')) return reply('p');
      if (r.url.path.contains('predicate-response'))
        return reply({'success': true});
      if (r.url.path.endsWith('add-request')) {
        writes++;
        token.cancel();
        return reply('r');
      }
      if (r.url.path.contains('add-drop-response'))
        return reply({'success': true});
      return reply([
        {'id': 3}
      ]);
    }))
      ..setAuthorization('token');
    expect(
        (await api.addCourse(1, 2, 3, 0, cancellation: token)).success, isTrue);
    expect(writes, 1);
    api.close();
  });

  test('HTTP requests time out even if transport never returns', () async {
    final api = ApiService(
        requestTimeout: const Duration(milliseconds: 20),
        client: MockClient((_) => Completer<http.Response>().future))
      ..setAuthorization('token');
    await expectLater(api.getCountInfo(3), throwsA(isA<TimeoutException>()));
    api.close();
  });

  for (final committed in [false, true]) {
    test('lost write response reconciles committed=$committed', () async {
      var writes = 0;
      final api = ApiService(
          requestTimeout: const Duration(milliseconds: 20),
          client: MockClient((r) async {
            if (r.url.path.endsWith('add-predicate')) return reply('p');
            if (r.url.path.contains('predicate-response'))
              return reply({'success': true});
            if (r.url.path.endsWith('add-request')) {
              writes++;
              return Completer<http.Response>().future;
            }
            return reply(committed
                ? [
                    {'id': 3}
                  ]
                : []);
          }))
        ..setAuthorization('token');
      final result = await api.addCourse(1, 2, 3, 0);
      expect(result.outcome,
          committed ? ActionOutcome.success : ActionOutcome.uncertain);
      expect(writes, 1);
      api.close();
    });
  }

  test('401 before submission is classified and response body is not exposed',
      () async {
    final api = ApiService(
        client:
            MockClient((_) async => http.Response('secret-token-body', 401)))
      ..setAuthorization('token');
    final result = await api.dropCourse(1, 2, 3);
    expect(result.authExpired, isTrue);
    expect(result.message, isNot(contains('secret-token-body')));
    api.close();
  });

  test('drop verifies removal from selected courses', () async {
    final responses = [
      reply('p'),
      reply({'success': true}),
      reply('r'),
      reply({'success': true}),
      reply([])
    ];
    final api =
        ApiService(client: MockClient((_) async => responses.removeAt(0)))
          ..setAuthorization('token');
    expect((await api.dropCourse(1, 2, 3)).success, isTrue);
    api.close();
  });

  test('business rejection never submits a write', () async {
    var calls = 0;
    final api = ApiService(
        client: MockClient((_) async => ++calls == 1
            ? reply('p')
            : reply({'success': false, 'errorMessage': '时间冲突'})))
      ..setAuthorization('token');
    final result = await api.addCourse(1, 2, 3, 0);
    expect(result.outcome, ActionOutcome.rejected);
    expect(result.message, '时间冲突');
    expect(calls, 2);
    api.close();
  });
}
