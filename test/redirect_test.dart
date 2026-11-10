@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flightbyte/flightbyte.dart';
import 'package:test/test.dart';

const _key = 'frk_test_secret';
const _country = {'code': 'TR', 'name': 'Türkiye'};

/// A local server that records the `x-api-key` of every request it receives.
final class _Server {
  _Server._(this.server);

  static Future<_Server> start(
      Future<void> Function(HttpRequest request) handle) async {
    final s = _Server._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));
    s.server.listen((request) async {
      s.keys.add(request.headers.value('x-api-key'));
      await handle(request);
    });
    return s;
  }

  final HttpServer server;
  final List<String?> keys = [];

  int get port => server.port;

  Future<void> close() => server.close(force: true);
}

Future<void> _json(HttpRequest request, Object body) async {
  request.response
    ..headers.contentType = ContentType.json
    ..write(jsonEncode(body));
  await request.response.close();
}

Future<void> _redirect(HttpRequest request, String location) async {
  request.response
    ..statusCode = HttpStatus.found
    ..headers.set(HttpHeaders.locationHeader, location);
  await request.response.close();
}

void main() {
  // `other` stands in for a host the API should never hand the key to.
  late _Server other;
  late _Server api;

  setUp(() async {
    other = await _Server.start((request) => _json(request, _country));
  });

  tearDown(() async {
    await api.close();
    await other.close();
  });

  FlightByteClient clientFor(_Server server) => FlightByteClient(
        apiKey: _key,
        baseUrl: Uri.parse('http://127.0.0.1:${server.port}/v1'),
      );

  Future<void> expectRefused(String location) async {
    api = await _Server.start((request) => _redirect(request, location));
    final client = clientFor(api);
    addTearDown(client.close);

    await expectLater(
      client.countries.get('TR'),
      throwsA(isA<UnexpectedStatusException>()
          .having((e) => e.statusCode, 'statusCode', HttpStatus.found)
          .having((e) => e.headers['location'], 'location', location)
          .having((e) => e.message, 'message', contains('not followed'))),
    );
    expect(api.keys, [_key]);
    expect(other.keys, isEmpty, reason: 'the API key reached another host');
  }

  test('a redirect to another host is not followed', () async {
    // 127.0.0.1 and localhost are different hosts to the client.
    await expectRefused('http://localhost:${other.port}/v1/countries/TR');
  });

  test('a redirect to another port is not followed', () async {
    await expectRefused('http://127.0.0.1:${other.port}/v1/countries/TR');
  });

  test('a redirect on the same origin is followed with the key', () async {
    api = await _Server.start((request) {
      if (request.uri.path == '/v1/countries/TR') {
        return _redirect(request, '/v1/countries/tr');
      }
      return _json(request, _country);
    });
    final client = clientFor(api);
    addTearDown(client.close);

    final country = await client.countries.get('TR');
    expect(country.code, 'TR');
    expect(api.keys, [_key, _key]);
    expect(other.keys, isEmpty);
  });

  test('a same-origin redirect loop stops after five hops', () async {
    api =
        await _Server.start((request) => _redirect(request, request.uri.path));
    final client = clientFor(api);
    addTearDown(client.close);

    await expectLater(
      client.countries.get('TR'),
      throwsA(isA<UnexpectedStatusException>()),
    );
    expect(api.keys, hasLength(6));
  });
}
