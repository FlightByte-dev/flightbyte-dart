import 'package:flightbyte/flightbyte.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  // Signatures produced by Node's createHmac, exactly as the API signs them
  // (src/webhooks/webhook-signer.service.ts), so Dart and the server agree.
  final vectors = jsonFixture('webhook_vectors.json');
  final secret = vectors['secret']! as String;
  final signedAt = DateTime.fromMillisecondsSinceEpoch(
    (vectors['timestamp']! as int) * 1000,
    isUtc: true,
  );
  final cases = [
    for (final c in vectors['cases']! as List)
      (
        payload: fixture((c as Map)['file'] as String),
        signature: c['signature'] as String
      ),
  ];

  group('verify', () {
    test('accepts signatures made by the API', () {
      for (final c in cases) {
        expect(
          Webhook.isValid(
              payload: c.payload,
              signature: c.signature,
              secret: secret,
              now: signedAt),
          isTrue,
          reason: c.payload,
        );
      }
    });

    test('rejects the wrong secret', () {
      final c = cases.first;
      expect(
        () => Webhook.verify(
          payload: c.payload,
          signature: c.signature,
          secret: 'whsec_other',
          now: signedAt,
        ),
        throwsA(isA<WebhookSignatureException>()
            .having((e) => e.message, 'message', contains('does not match'))),
      );
    });

    test('rejects a tampered body', () {
      final c = cases.last;
      expect(
        Webhook.isValid(
          payload: c.payload.replaceFirst('A22', 'A23'),
          signature: c.signature,
          secret: secret,
          now: signedAt,
        ),
        isFalse,
      );
    });

    test('rejects a signing time outside the tolerance', () {
      final c = cases.first;
      final late = signedAt.add(const Duration(minutes: 5, seconds: 1));
      expect(
        () => Webhook.verify(
            payload: c.payload,
            signature: c.signature,
            secret: secret,
            now: late),
        throwsA(isA<WebhookSignatureException>()
            .having((e) => e.message, 'message', contains('tolerance'))),
      );
      expect(
        Webhook.isValid(
          payload: c.payload,
          signature: c.signature,
          secret: secret,
          now: signedAt.add(const Duration(minutes: 5)),
        ),
        isTrue,
      );
      expect(
        Webhook.isValid(
          payload: c.payload,
          signature: c.signature,
          secret: secret,
          now: late,
          tolerance: Duration.zero,
        ),
        isTrue,
      );
    });

    test('rejects missing and malformed headers', () {
      final payload = cases.first.payload;
      for (final header in [
        null,
        '',
        'v1=abc',
        't=abc,v1=abc',
        't=1788858600'
      ]) {
        expect(
          Webhook.isValid(
              payload: payload,
              signature: header,
              secret: secret,
              now: signedAt),
          isFalse,
          reason: '$header',
        );
      }
    });

    test('accepts any of several v1 signatures', () {
      final c = cases.first;
      final rotated = c.signature.replaceFirst('v1=', 'v1=${'0' * 64},v1=');
      expect(
        Webhook.isValid(
            payload: c.payload,
            signature: rotated,
            secret: secret,
            now: signedAt),
        isTrue,
      );
    });
  });

  test('sign produces what verify accepts, and what the API produces', () {
    final c = cases.first;
    expect(
        Webhook.sign(payload: c.payload, secret: secret, timestamp: signedAt),
        c.signature);
  });

  test('an empty secret is refused, not used as a key', () {
    final payload = cases.last.payload;
    for (final empty in ['', '   ']) {
      final forged = 't=${signedAt.millisecondsSinceEpoch ~/ 1000},'
          'v1=${'0' * 64}';
      expect(
        () => Webhook.verify(
          payload: payload,
          signature: forged,
          secret: empty,
          now: signedAt,
        ),
        throwsArgumentError,
      );
      expect(
        () => Webhook.isValid(
          payload: payload,
          signature: forged,
          secret: empty,
          now: signedAt,
        ),
        throwsArgumentError,
      );
      expect(
        () => Webhook.constructEvent(
          payload: payload,
          signature: forged,
          secret: empty,
          now: signedAt,
        ),
        throwsArgumentError,
      );
      expect(() => Webhook.sign(payload: payload, secret: empty),
          throwsArgumentError);
    }
  });

  test('constructEvent verifies, then decodes', () {
    final c = cases.last;
    final event = Webhook.constructEvent(
      payload: c.payload,
      signature: c.signature,
      secret: secret,
      now: signedAt,
    );
    expect(event.id, 'evt_2');
    expect(event.changes.single.message, contains('İstanbul'));
  });
}
