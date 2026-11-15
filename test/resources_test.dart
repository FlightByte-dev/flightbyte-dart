import 'package:flightbyte/flightbyte.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  group('flights', () {
    test('get sends the leg selector and refresh', () async {
      final h = Harness([Reply(200, jsonFixture('flight.json'))]);
      final flight = await h.client.flights.get(
        carrier: 'TK',
        flightNumber: '1',
        date: '2026-09-08',
        origin: 'IST',
        refresh: true,
      );
      expect(h.last.method, 'GET');
      expect(h.last.url.path, '/v1/flights/TK/1/2026-09-08');
      expect(h.last.url.queryParameters, {'origin': 'IST', 'refresh': 'true'});
      expect(flight.flightKey, 'TK1848:2026-09-08');
    });

    test('get sends no query when nothing is selected', () async {
      final h = Harness([Reply(200, jsonFixture('flight.json'))]);
      await h.client.flights
          .get(carrier: 'TK', flightNumber: '1848', date: '2026-09-08');
      expect(h.last.url.hasQuery, isFalse);
    });

    test('timeline', () async {
      final h = Harness([
        Reply(200, {
          'flightKey': 'TK1848:2026-09-08',
          'count': 1,
          'data': jsonFixture('flight.json')['timeline'],
        }),
      ]);
      final timeline = await h.client.flights.timeline(
        carrier: 'TK',
        flightNumber: '1848',
        date: '2026-09-08',
        destination: 'CDG',
      );
      expect(h.last.url.path, '/v1/flights/TK/1848/2026-09-08/timeline');
      expect(h.last.url.queryParameters, {'destination': 'CDG'});
      expect(timeline.entries.single.title, 'Time Adjustment');
      expect(timeline.count, 1);
    });

    test('timeline count is read from the response', () async {
      final h = Harness([
        Reply(200, {
          'flightKey': 'TK1848:2026-09-08',
          'count': 7,
          'data': jsonFixture('flight.json')['timeline'],
        }),
      ]);
      final timeline = await h.client.flights
          .timeline(carrier: 'TK', flightNumber: '1848', date: '2026-09-08');
      expect(timeline.count, 7);
      expect(timeline.entries, hasLength(1));
    });

    test('timeline count falls back to the entry count', () async {
      final h = Harness([
        Reply(200, {
          'flightKey': 'TK1848:2026-09-08',
          'data': jsonFixture('flight.json')['timeline'],
        }),
      ]);
      final timeline = await h.client.flights
          .timeline(carrier: 'TK', flightNumber: '1848', date: '2026-09-08');
      expect(timeline.count, 1);
    });
  });

  group('countries', () {
    final tr = <String, Object?>{
      'code': 'TR',
      'name': 'Türkiye',
      'emoji': '🇹🇷',
      'flagSvg': 'https://api.flightbyte.dev/v1/flags/tr.svg',
      'flagSvgSquare': 'https://api.flightbyte.dev/v1/flags/tr.svg?shape=1x1',
      'alpha2': 'TR',
      'hasFlag': true,
    };

    test('list', () async {
      final h = Harness([
        Reply(200, {
          'count': 1,
          'data': [tr],
        }),
      ]);
      final countries = await h.client.countries.list(lang: 'tr');
      expect(h.last.url.toString(),
          'https://api.flightbyte.dev/v1/countries?lang=tr');
      expect(countries.single.hasFlag, isTrue);
    });

    test('get', () async {
      final h = Harness([Reply(200, tr)]);
      final country = await h.client.countries.get('TR');
      expect(h.last.url.path, '/v1/countries/TR');
      expect(country.alpha2, 'TR');
    });

    test('flagUrl', () {
      final h = Harness([Reply(200, tr)]);
      expect(
        h.client.countries.flagUrl('TR').toString(),
        'https://api.flightbyte.dev/v1/flags/tr.svg',
      );
      expect(
        h.client.countries.flagUrl('tr', square: true).toString(),
        'https://api.flightbyte.dev/v1/flags/tr.svg?shape=1x1',
      );
    });
  });

  group('subscriptions', () {
    final sub = jsonFixture('subscription.json');

    test('create sends the body and the idempotency key', () async {
      final h = Harness([
        Reply(201, {
          ...{...sub}..remove('secretHint'),
          'secret': 'whsec_AbCdEfGhIjKlMnOpQrStwxyz',
          'reused': false,
          'flight': jsonFixture('flight.json'),
        }),
      ]);
      final created = await h.client.subscriptions.create(
        carrier: 'TK',
        flightNumber: '1848',
        date: '2026-09-08',
        webhookUrl: Uri.parse('https://example.com/hooks/flights'),
        events: [FlightChangeType.departed, FlightChangeType.delayIncreased],
        delayThresholdMinutes: 10,
        metadata: {'booking': '42'},
        idempotencyKey: 'booking-42',
      );
      expect(h.last.method, 'POST');
      expect(h.last.url.path, '/v1/subscriptions');
      expect(h.last.headers['idempotency-key'], 'booking-42');
      expect(h.last.headers['content-type'], startsWith('application/json'));
      expect(h.lastJson, {
        'carrier': 'TK',
        'flightNumber': '1848',
        'date': '2026-09-08',
        'webhookUrl': 'https://example.com/hooks/flights',
        'events': ['flight.departed', 'delay.increased'],
        'delayThresholdMinutes': 10,
        'metadata': {'booking': '42'},
      });
      expect(created.secret, 'whsec_AbCdEfGhIjKlMnOpQrStwxyz');
      expect(created.subscription.secretHint, 'whsec_AbCdE...wxyz');
      expect(created.reused, isFalse);
      expect(created.flight!.flightNumber, '1848');
    });

    test('create refuses FlightChangeType.unknown', () {
      final h = Harness([Reply(201, sub)]);
      expect(
        () => h.client.subscriptions.create(
          carrier: 'TK',
          flightNumber: '1848',
          date: '2026-09-08',
          webhookUrl: Uri.parse('https://example.com'),
          events: [FlightChangeType.unknown],
        ),
        throwsArgumentError,
      );
    });

    test('list sends the filters', () async {
      final h = Harness([
        Reply(200, {
          'total': 1,
          'limit': 10,
          'offset': 5,
          'data': [sub],
        }),
      ]);
      final page = await h.client.subscriptions.list(
        status: SubscriptionStatus.paused,
        carrier: 'TK',
        limit: 10,
        offset: 5,
      );
      expect(h.last.url.queryParameters, {
        'status': 'paused',
        'carrier': 'TK',
        'limit': '10',
        'offset': '5',
      });
      expect(page.items.single.id, sub['id']);
    });

    test('listAll walks every page', () async {
      final h = Harness([
        Reply(200, {
          'total': 3,
          'limit': 2,
          'offset': 0,
          'data': [sub, sub],
        }),
        Reply(200, {
          'total': 3,
          'limit': 2,
          'offset': 2,
          'data': [sub],
        }),
      ]);
      final all = await h.client.subscriptions.listAll(pageSize: 2).toList();
      expect(all, hasLength(3));
      expect(
          h.requests.map((r) => r.url.queryParameters['offset']), ['0', '2']);
    });

    test('update sends only the given fields', () async {
      final h = Harness([Reply(200, sub)]);
      await h.client.subscriptions.update('sub_1', delayThresholdMinutes: 30);
      expect(h.last.method, 'PATCH');
      expect(h.last.url.path, '/v1/subscriptions/sub_1');
      expect(h.lastJson, {'delayThresholdMinutes': 30});
    });

    test('delete accepts a 204 with no body', () async {
      final h = Harness([Reply(204)]);
      await h.client.subscriptions.delete('sub_1');
      expect(h.last.method, 'DELETE');
    });

    test('pause and resume accept 201', () async {
      final h = Harness([Reply(201, sub)]);
      await h.client.subscriptions.pause('sub_1');
      expect(h.last.url.path, '/v1/subscriptions/sub_1/pause');
      await h.client.subscriptions.resume('sub_1');
      expect(h.last.url.path, '/v1/subscriptions/sub_1/resume');
      expect(h.requests.every((r) => r.method == 'POST'), isTrue);
    });

    test('sendTest returns the event id', () async {
      final h = Harness([
        Reply(201, {'eventId': 'evt_9'}),
      ]);
      expect(await h.client.subscriptions.sendTest('sub_1'), 'evt_9');
      expect(h.last.url.path, '/v1/subscriptions/sub_1/test');
    });

    test('deliveries and events', () async {
      final h = Harness([
        Reply(200, {
          'count': 1,
          'data': [
            {
              'eventId': 'evt_1',
              'attempt': 2,
              'status': 'failed',
              'httpStatus': 500,
              'error': 'HTTP 500',
              'durationMs': 120,
              'at': '2026-09-08T09:10:00.000Z',
              'changeTypes': ['departure.gate.changed'],
            },
          ],
        }),
        Reply(200, {
          'count': 1,
          'data': [jsonFixture('webhook_flight_updated.json')],
        }),
      ]);
      final deliveries =
          await h.client.subscriptions.deliveries('sub_1', limit: 5);
      expect(h.last.url.toString(),
          endsWith('/subscriptions/sub_1/deliveries?limit=5'));
      expect(deliveries.single.status, DeliveryStatus.failed);
      expect(deliveries.single.httpStatus, 500);

      final events = await h.client.subscriptions.events('sub_1');
      expect(h.last.url.path, '/v1/subscriptions/sub_1/events');
      expect(events.single.type, WebhookEventType.flightUpdated);
    });

    test('secret and rotateSecret', () async {
      final h = Harness([
        Reply(200, {'secret': 'whsec_a'}),
        Reply(201, {'secret': 'whsec_b'}),
      ]);
      expect(await h.client.subscriptions.secret('sub_1'), 'whsec_a');
      expect(h.last.method, 'GET');
      expect(await h.client.subscriptions.rotateSecret('sub_1'), 'whsec_b');
      expect(h.last.method, 'POST');
      expect(h.last.url.path, '/v1/subscriptions/sub_1/secret/rotate');
    });

    test('an empty id is refused before anything is sent', () {
      final h = Harness([
        Reply(200, {'total': 0, 'data': <Object?>[]})
      ]);
      final s = h.client.subscriptions;
      for (final call in <Future<Object?> Function()>[
        () => s.get(''),
        () => s.update(' ', delayThresholdMinutes: 5),
        () => s.delete(''),
        () => s.pause(''),
        () => s.resume(''),
        () => s.sendTest(''),
        () => s.deliveries(''),
        () => s.events(''),
        () => s.secret(''),
        () => s.rotateSecret(''),
      ]) {
        expect(call, throwsArgumentError);
      }
      expect(h.requests, isEmpty);
    });
  });

  test('empty flight, country and create parameters are refused', () {
    final h = Harness([Reply(200, <String, Object?>{})]);
    final c = h.client;
    expect(
      () => c.flights.get(carrier: '', flightNumber: '1', date: 'd'),
      throwsArgumentError,
    );
    expect(
      () => c.flights.timeline(carrier: 'TK', flightNumber: ' ', date: 'd'),
      throwsArgumentError,
    );
    expect(() => c.countries.get(''), throwsArgumentError);
    expect(() => c.countries.flagUrl(''), throwsArgumentError);
    expect(
      () => c.subscriptions.create(
        carrier: 'TK',
        flightNumber: '1',
        date: '',
        webhookUrl: Uri(),
      ),
      throwsArgumentError,
    );
    expect(h.requests, isEmpty);
  });
}
