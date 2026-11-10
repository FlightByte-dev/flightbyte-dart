import 'dart:convert';
import 'dart:io';

import 'package:flightbyte/flightbyte.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  group('FlightSnapshot', () {
    final flight = FlightSnapshot.fromJson(jsonFixture('flight.json'));

    test('decodes every level', () {
      expect(flight.flightKey, 'TK1848:2026-09-08');
      expect(flight.carrier.icao, 'THY');
      expect(flight.codeshares.single.flightNumber, '3160');
      expect(flight.departure.airport.city, 'İstanbul');
      expect(flight.departure.airport.country.emoji, '🇹🇷');
      expect(flight.departure.times.scheduledGate!.utc,
          DateTime.utc(2026, 9, 8, 9, 10));
      expect(flight.departure.times.scheduledGate!.local,
          '2026-09-08T12:10:00.000');
      expect(flight.departure.times.bestGate!.utc,
          DateTime.utc(2026, 9, 8, 9, 25));
      expect(flight.departure.delayMinutes, 15);
      expect(flight.arrival.delayMinutes, -5);
      expect(flight.arrival.airport.code, isNull);
      expect(flight.arrival.times.estimatedGate, isNull);
      expect(flight.status.phase, FlightPhase.scheduled);
      expect(flight.status.phase.isTerminal, isFalse);
      expect(flight.status.delayed, isTrue);
      expect(flight.equipment.tailNumber, 'TC-LTP');
      expect(flight.duration.scheduledMinutes, 225);
      expect(flight.timeline.single.events,
          ['Estimated Gate Departure changed to 12:25']);
      expect(flight.alternates.single.selected, isTrue);
      expect(flight.diverted, isNull);
      expect(flight.cached, isTrue);
    });

    test('survives a JSON round trip', () {
      final again = FlightSnapshot.fromJson(
        (jsonDecode(jsonEncode(flight.toJson())) as Map)
            .cast<String, Object?>(),
      );
      expect(jsonEncode(again.toJson()), jsonEncode(flight.toJson()));
    });

    test('tolerates missing optional sections', () {
      final json = jsonFixture('flight.json')
        ..remove('equipment')
        ..remove('duration')
        ..remove('timeline')
        ..remove('alternates')
        ..remove('codeshares')
        ..remove('fingerprint')
        ..remove('cached');
      final minimal = FlightSnapshot.fromJson(json);
      expect(minimal.timeline, isEmpty);
      expect(minimal.equipment.name, isNull);
      expect(minimal.cached, isFalse);
    });

    test('a missing required field names the field', () {
      final json = jsonFixture('flight.json')..remove('flightKey');
      expect(
        () => FlightSnapshot.fromJson(json),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'message', contains('flightKey'))),
      );
    });

    test('an unknown phase decodes to unknown and keeps the raw value', () {
      final json = jsonFixture('flight.json');
      (json['status']! as Map)['phase'] = 'taxiing';
      final status = FlightSnapshot.fromJson(json).status;
      expect(status.phase, FlightPhase.unknown);
      expect(status.phaseValue, 'taxiing');
    });
  });

  group('Subscription', () {
    test('decodes and keeps unknown change types', () {
      final sub = Subscription.fromJson(jsonFixture('subscription.json'));
      expect(sub.status, SubscriptionStatus.active);
      expect(sub.events, [
        FlightChangeType.departed,
        FlightChangeType.departureGateChanged,
        FlightChangeType.unknown,
      ]);
      expect(sub.eventValues.last, 'some.future.type');
      expect(sub.headers, {'x-team': 'ops'});
      expect(sub.lastChangeAt, isNull);
      expect(sub.failedCount, 1);
    });

    test('masks a full secret like the API', () {
      expect(
        Subscription.maskSecret('whsec_AbCdEfGhIjKlMnOpQrStwxyz'),
        'whsec_AbCdE...wxyz',
      );
    });

    test('page reports whether more follow', () {
      final page = SubscriptionPage.fromJson({
        'total': 3,
        'limit': 2,
        'offset': 0,
        'data': [
          jsonFixture('subscription.json'),
          jsonFixture('subscription.json')
        ],
      });
      expect(page.hasMore, isTrue);
      expect(page.nextOffset, 2);
    });
  });

  group('WebhookEvent', () {
    test('decodes changes with scalar values', () {
      final event =
          WebhookEvent.fromJson(jsonFixture('webhook_flight_updated.json'));
      expect(event.type, WebhookEventType.flightUpdated);
      expect(event.changes.single.type, FlightChangeType.departureGateChanged);
      expect(event.changes.single.from, 'A11');
      expect(event.changes.single.deltaMinutes, isNull);
      expect(event.metadata, {'booking': '42'});
      expect(event.flight, isNull);
    });
  });

  test('formatDate gives YYYY-MM-DD from the calendar fields', () {
    expect(FlightByteClient.formatDate(DateTime(2026, 9, 8, 23, 59)),
        '2026-09-08');
  });

  test('packageVersion matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(r'^version:\s*(\S+)', multiLine: true)
        .firstMatch(pubspec)!
        .group(1);
    expect(packageVersion, version);
  });
}
