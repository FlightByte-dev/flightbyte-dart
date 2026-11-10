import 'package:flightbyte/flightbyte.dart';
import 'package:test/test.dart';

import 'helpers.dart';

Future<FlightByteApiException> _fail(Reply reply) async {
  final h = Harness([reply]);
  try {
    await h.client.flights
        .get(carrier: 'TK', flightNumber: '1848', date: '2026-09-08');
  } on FlightByteApiException catch (e) {
    return e;
  }
  fail('expected an exception');
}

Map<String, Object?> _body(int status, Object message,
        [Map<String, Object?> extra = const {}]) =>
    {
      'statusCode': status,
      'error': 'Error',
      'message': message,
      'path': '/v1/flights/TK/1848/2026-09-08',
      'timestamp': '2026-09-08T09:10:00.000Z',
      'requestId': 'req-1',
      ...extra,
    };

void main() {
  test('400 keeps every validation message', () async {
    final e = await _fail(
        Reply(400, _body(400, ['carrier must match', 'date must be a date'])));
    expect(e, isA<BadRequestException>());
    expect(e.messages, ['carrier must match', 'date must be a date']);
    expect(e.message, 'carrier must match date must be a date');
    expect(e.requestId, 'req-1');
    expect(e.toString(), contains('(request req-1)'));
  });

  test('400 for an ambiguous flight lists the legs', () async {
    final e = await _fail(Reply(
      400,
      _body(400,
          'TK1 operates 2 legs on 2026-09-08. Pass "origin" to choose one.', {
        'legs': [
          {
            'origin': 'SAW',
            'destination': 'AMS',
            'carrier': 'AJA',
            'scheduledDepartureLocal': '08:45',
            'flightId': '111',
          },
          {
            'origin': 'IST',
            'destination': 'JFK',
            'carrier': 'TK',
            'flightId': '222'
          },
        ],
      }),
    )) as BadRequestException;
    expect(e.legs.map((l) => l.origin), ['SAW', 'IST']);
    expect(e.legs.first.scheduledDepartureLocal, '08:45');
    expect(e.legs.last.flightId, '222');
  });

  test('401', () async {
    expect(
        await _fail(
            Reply(401, _body(401, 'A valid X-API-Key header is required.'))),
        isA<AuthenticationException>());
  });

  test('402 carries the usage numbers', () async {
    final e = await _fail(Reply(
      402,
      _body(402, 'Used up', {
        'code': 'overage_cap_reached',
        'limit': 350,
        'used': 350,
        'resetsAt': '2026-11-18T00:00:00.000Z',
        'capCents': 2000,
      }),
    )) as PaymentRequiredException;
    expect(e.code, 'overage_cap_reached');
    expect(e.limit, 350);
    expect(e.used, 350);
    expect(e.resetsAt, DateTime.utc(2026, 11, 18));
    expect(e.capCents, 2000);
  });

  test('403 carries the code', () async {
    final e = await _fail(
        Reply(403, _body(403, 'Suspended', {'code': 'account_suspended'})));
    expect(e, isA<PermissionDeniedException>());
    expect(e.code, 'account_suspended');
  });

  test('404', () async {
    expect(
        await _fail(
            Reply(404, _body(404, 'TK1848 did not operate on 2026-09-08.'))),
        isA<NotFoundException>());
  });

  test('429 reads retryAfter from the body', () async {
    final e = await _fail(Reply(
      429,
      _body(
          429, 'Quota exceeded', {'window': 'minute', 'retryAfterSeconds': 12}),
      {'retry-after': '12'},
    )) as RateLimitException;
    expect(e.window, 'minute');
    expect(e.retryAfter, const Duration(seconds: 12));
  });

  test('429 falls back to the Retry-After header', () async {
    final e =
        await _fail(Reply(429, '', {'retry-after': '7'})) as RateLimitException;
    expect(e.retryAfter, const Duration(seconds: 7));
  });

  test('502 is an UpstreamException', () async {
    expect(await _fail(Reply(502, _body(502, 'Provider down'))),
        isA<UpstreamException>());
  });

  test('a 5xx with an HTML body is a ServerException', () async {
    final e = await _fail(Reply(503, '<html>Service Unavailable</html>'));
    expect(e, isA<ServerException>());
    expect(e.statusCode, 503);
    expect(e.body, isEmpty);
    expect(e.rawBody, contains('Service Unavailable'));
    expect(e.message, 'HTTP 503');
  });

  test('an unmapped 4xx is an UnexpectedStatusException', () async {
    expect(await _fail(Reply(418, _body(418, 'teapot'))),
        isA<UnexpectedStatusException>());
  });

  test('the hierarchy is exhaustive in a switch', () async {
    final FlightByteException e = await _fail(Reply(404, _body(404, 'x')));
    final label = switch (e) {
      FlightByteConnectionException() => 'network',
      BadRequestException() => 'bad',
      AuthenticationException() => 'auth',
      PaymentRequiredException() => 'pay',
      PermissionDeniedException() => 'forbidden',
      NotFoundException() => 'missing',
      RateLimitException() => 'slow',
      UpstreamException() => 'upstream',
      ServerException() => 'server',
      UnexpectedStatusException() => 'other',
    };
    expect(label, 'missing');
  });
}
