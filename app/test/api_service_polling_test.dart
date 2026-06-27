import 'dart:async';
import 'dart:convert';

import 'package:ecnu_eams_client/models/polling_config.dart';
import 'package:ecnu_eams_client/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class QueueClient extends http.BaseClient {
  final List<http.Response> responses;
  final List<http.BaseRequest> requests = [];

  QueueClient(this.responses);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    if (responses.isEmpty) {
      throw StateError('No response queued for ${request.url}');
    }
    final response = responses.removeAt(0);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      reasonPhrase: response.reasonPhrase,
    );
  }
}

http.Response api(dynamic data, {int result = 0}) {
  return http.Response(
    jsonEncode({
      'result': result,
      'message': result == 0 ? null : 'bad',
      'data': data
    }),
    200,
  );
}

void main() {
  test('addCourse polls predicate and add-drop responses until success',
      () async {
    final client = QueueClient([
      api('predicate-id'),
      api(null),
      api({
        'success': true,
        'requestId': 'predicate-id',
        'result': {'1': null}
      }),
      api('request-id'),
      api({
        'success': true,
        'requestId': 'request-id',
        'result': {'1': null}
      }),
    ]);
    final service =
        ApiService(client: client, authorizationProvider: () async => 'token');

    final result = await service.addCourse(
      1,
      2,
      3,
      4,
      polling: const PollingConfig(
          timeout: Duration(seconds: 3), interval: Duration(milliseconds: 1)),
    );

    expect(result.success, isTrue);
    expect(result.requestId, 'request-id');
    expect(result.lessonResults, {'1': null});
    expect(result.attempts, 3);
  });

  test('addCourse reports predicate failure without submitting add request',
      () async {
    final client = QueueClient([
      api('predicate-id'),
      api({'success': false, 'errorMessage': 'time conflict'}),
    ]);
    final service =
        ApiService(client: client, authorizationProvider: () async => 'token');

    final result = await service.addCourse(
      1,
      2,
      3,
      0,
      polling: const PollingConfig(
          timeout: Duration(seconds: 1), interval: Duration(milliseconds: 1)),
    );

    expect(result.success, isFalse);
    expect(result.message, 'time conflict');
    expect(client.requests.length, 2);
  });

  test('dropCourse returns an auth-expired result on 401', () async {
    final client = QueueClient([http.Response('expired', 401)]);
    final service =
        ApiService(client: client, authorizationProvider: () async => 'token');

    final result = await service.dropCourse(
      1,
      2,
      3,
      polling: const PollingConfig(
          timeout: Duration(seconds: 1), interval: Duration(milliseconds: 1)),
    );

    expect(result.success, isFalse);
    expect(result.authExpired, isTrue);
  });
}
