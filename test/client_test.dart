import 'dart:async';

import 'package:flightbyte/flightbyte.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  test('sends the API key, accept and user agent headers', () async {
    final h = Harness([Reply(200, jsonFixture('flight.json'))]);
    await h.client.flights
        .get(carrier: 'TK', flightNumber: '1848', date: '2026-09-08');
    expect(h.last.headers['x-api-key'], 'frk_test_key');
    expect(h.last.headers['accept'], 'application/json');
    expect(h.last.headers['user-agent'], 'flightbyte-dart/$packageVersion');
  });

  test('defaults to the production base URL', () async {
    final h = Harness([Reply(200, jsonFixture('flight.json'))]);
    await h.client.flights
        .get(carrier: 'TK', flightNumber: '1848', date: '2026-09-08');
    expect(h.last.url.toString(),
        'https://api.flightbyte.dev/v1/flights/TK/1848/2026-09-08');
  });

  test('joins a custom base URL with or without a trailing slash', () async {
    for (final base in [
      'http://localhost:3000/v1',
      'http://localhost:3000/v1/'
    ]) {
      final h = Harness([Reply(200, jsonFixture('flight.json'))],
          baseUrl: Uri.parse(base));
      await h.client.flights
          .get(carrier: 'TK', flightNumber: '1848', date: '2026-09-08');
      expect(h.last.url.toString(),
          'http://localhost:3000/v1/flights/TK/1848/2026-09-08');
    }
  });

  test('encodes path segments', () async {
    final h = Harness([Reply(200, jsonFixture('subscription.json'))]);
    await h.client.subscriptions.get('sub/../x y');
    expect(h.last.url.path, '/v1/subscriptions/sub%2F..%2Fx%20y');
  });

  test('reads the rate-limit headers', () async {
    final h = Harness([
      Reply(200, jsonFixture('flight.json'), {
        'x-ratelimit-limit-minute': '60',
        'x-ratelimit-remaining-minute': '59',
        'x-ratelimit-reset-minute': '1788858660',
      }),
    ]);
    expect(h.client.lastRateLimit, isNull);
    await h.client.flights
        .get(carrier: 'TK', flightNumber: '1848', date: '2026-09-08');
    final minute = h.client.lastRateLimit!.minute!;
    expect(minute.limit, 60);
    expect(minute.remaining, 59);
    expect(minute.resetAt, DateTime.utc(2026, 9, 8, 9, 11));
    expect(h.client.lastRateLimit!.day, isNull);
  });

  test('a network failure is a FlightByteConnectionException', () async {
    final client = FlightByteClient(
      apiKey: 'k',
      httpClient: MockClient(
          (_) async => throw http.ClientException('Connection refused')),
    );
    await expectLater(
      client.flights.get(carrier: 'TK', flightNumber: '1', date: '2026-09-08'),
      throwsA(isA<FlightByteConnectionException>()
          .having((e) => e.message, 'message', contains('Connection refused'))),
    );
  });

  test('any exception from the HTTP client is a FlightByteConnectionException',
      () async {
    final client = FlightByteClient(
      apiKey: 'k',
      httpClient: MockClient((_) async => throw const _TlsFailure()),
    );
    await expectLater(
      client.flights.get(carrier: 'TK', flightNumber: '1', date: '2026-09-08'),
      throwsA(isA<FlightByteConnectionException>()
          .having((e) => e.cause, 'cause', isA<_TlsFailure>())
          .having((e) => e.message, 'message', contains('handshake'))),
    );
  });

  test('a timeout aborts the request in flight', () async {
    final inner = _Hanging();
    final client = FlightByteClient(
      apiKey: 'k',
      timeout: const Duration(milliseconds: 20),
      httpClient: inner,
    );
    await expectLater(
      client.flights.get(carrier: 'TK', flightNumber: '1', date: '2026-09-08'),
      throwsA(isA<FlightByteConnectionException>()
          .having((e) => e.message, 'message', contains('after 20 ms'))),
    );
    await inner.aborted.future.timeout(const Duration(seconds: 1));
  });

  test('a slow response times out', () async {
    final never = Completer<http.Response>();
    final client = FlightByteClient(
      apiKey: 'k',
      timeout: const Duration(milliseconds: 20),
      httpClient: MockClient((_) => never.future),
    );
    await expectLater(
      client.flights.get(carrier: 'TK', flightNumber: '1', date: '2026-09-08'),
      throwsA(isA<FlightByteConnectionException>()
          .having((e) => e.message, 'message', contains('timed out'))),
    );
  });

  test('a 2xx that is not JSON is a FormatException', () async {
    final h = Harness([Reply(200, '<html>proxy</html>')]);
    await expectLater(
      h.client.flights
          .get(carrier: 'TK', flightNumber: '1', date: '2026-09-08'),
      throwsA(isA<FormatException>()
          .having((e) => e.message, 'message', contains('proxy'))),
    );
  });

  test('an empty API key is rejected', () {
    expect(() => FlightByteClient(apiKey: '  '), throwsArgumentError);
  });

  test('close leaves a client it was given open', () async {
    var closed = false;
    final inner = _CloseTracking(() => closed = true);
    FlightByteClient(apiKey: 'k', httpClient: inner).close();
    expect(closed, isFalse);
  });
}

final class _TlsFailure implements Exception {
  const _TlsFailure();

  @override
  String toString() => 'HandshakeException: handshake failed';
}

/// Never answers, and completes [aborted] when the request is aborted.
final class _Hanging extends http.BaseClient {
  final aborted = Completer<void>();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final trigger = request is http.Abortable ? request.abortTrigger : null;
    if (trigger == null) return Completer<http.StreamedResponse>().future;
    await trigger;
    aborted.complete();
    throw http.RequestAbortedException(request.url);
  }
}

final class _CloseTracking extends http.BaseClient {
  _CloseTracking(this.onClose);

  final void Function() onClose;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      throw UnimplementedError();

  @override
  void close() => onClose();
}
