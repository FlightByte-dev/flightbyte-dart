import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'json.dart';
import 'models/webhook_event.dart';

/// The signature on a webhook did not verify.
final class WebhookSignatureException implements Exception {
  /// Creates a [WebhookSignatureException].
  const WebhookSignatureException(this.message);

  /// Why verification failed.
  final String message;

  @override
  String toString() => 'WebhookSignatureException: $message';
}

/// Verifies and decodes the webhooks FlightByte posts to your receiver.
///
/// Each delivery carries an `x-flightbyte-signature` header of the form
/// `t=<unix seconds>,v1=<hex>`, where the hex is HMAC-SHA256 of
/// `"<t>.<raw body>"` keyed with the subscription's signing secret.
///
/// This belongs on your server. The signing secret must never ship inside a
/// mobile or web app.
///
/// ```dart
/// // With package:shelf
/// Future<Response> handle(Request request) async {
///   final payload = await request.readAsString();
///   try {
///     final event = Webhook.constructEvent(
///       payload: payload,
///       signature: request.headers[Webhook.signatureHeader],
///       secret: signingSecret,
///     );
///     // Deduplicate on event.id: it is the same across retries.
///     return Response.ok('ok');
///   } on WebhookSignatureException {
///     return Response.badRequest();
///   }
/// }
/// ```
abstract final class Webhook {
  /// Header carrying the signature.
  static const signatureHeader = 'x-flightbyte-signature';

  /// Header carrying the signing timestamp, in unix seconds.
  static const timestampHeader = 'x-flightbyte-timestamp';

  /// Header carrying the event id.
  static const eventIdHeader = 'x-flightbyte-event-id';

  /// Header carrying the event type.
  static const eventTypeHeader = 'x-flightbyte-event-type';

  /// Header carrying the subscription id.
  static const subscriptionIdHeader = 'x-flightbyte-subscription-id';

  /// Header carrying the delivery attempt number, starting at 1.
  static const deliveryAttemptHeader = 'x-flightbyte-delivery-attempt';

  /// How far the signing time may be from now: 5 minutes, as on the API.
  static const defaultTolerance = Duration(minutes: 5);

  /// Checks [signature] (the `x-flightbyte-signature` header) against the raw
  /// request body [payload] and the subscription's [secret].
  ///
  /// [payload] must be the body exactly as received, before any JSON parsing.
  /// A signing time further than [tolerance] from [now] is rejected, which
  /// stops replays; pass [Duration.zero] to skip that check.
  ///
  /// Throws a [WebhookSignatureException] when the signature does not verify,
  /// and an [ArgumentError] when [secret] is empty: anyone can sign with an
  /// empty key, so it usually means the secret was not configured.
  static void verify({
    required String payload,
    required String? signature,
    required String secret,
    Duration tolerance = defaultTolerance,
    DateTime? now,
  }) {
    _checkSecret(secret);
    if (signature == null || signature.trim().isEmpty) {
      throw const WebhookSignatureException('The signature header is missing.');
    }

    String? timestamp;
    final provided = <String>[];
    for (final part in signature.split(',')) {
      final index = part.indexOf('=');
      if (index <= 0) continue;
      final key = part.substring(0, index).trim();
      final value = part.substring(index + 1).trim();
      if (key == 't') timestamp = value;
      if (key == 'v1') provided.add(value.toLowerCase());
    }

    final seconds = timestamp == null ? null : int.tryParse(timestamp);
    if (seconds == null) {
      throw const WebhookSignatureException(
          'The signature header has no valid timestamp.');
    }
    if (provided.isEmpty) {
      throw const WebhookSignatureException(
          'The signature header has no v1 signature.');
    }

    if (tolerance > Duration.zero) {
      final nowSeconds = (now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
      if ((nowSeconds - seconds).abs() > tolerance.inSeconds) {
        throw const WebhookSignatureException(
          'The signature timestamp is outside the tolerance window.',
        );
      }
    }

    final expected = _hmac(secret, '$timestamp.$payload');
    if (!provided
        .any((candidate) => _constantTimeEquals(candidate, expected))) {
      throw const WebhookSignatureException(
          'The signature does not match the payload.');
    }
  }

  /// Whether [signature] verifies; see [verify].
  static bool isValid({
    required String payload,
    required String? signature,
    required String secret,
    Duration tolerance = defaultTolerance,
    DateTime? now,
  }) {
    try {
      verify(
        payload: payload,
        signature: signature,
        secret: secret,
        tolerance: tolerance,
        now: now,
      );
      return true;
    } on WebhookSignatureException {
      return false;
    }
  }

  /// Verifies the signature (see [verify]), then decodes the event.
  ///
  /// Throws a [WebhookSignatureException] when the signature does not verify,
  /// and a [FormatException] when the verified body is not a webhook event.
  static WebhookEvent constructEvent({
    required String payload,
    required String? signature,
    required String secret,
    Duration tolerance = defaultTolerance,
    DateTime? now,
  }) {
    verify(
      payload: payload,
      signature: signature,
      secret: secret,
      tolerance: tolerance,
      now: now,
    );
    return WebhookEvent.fromJson(
        asJson(jsonDecode(payload), 'the webhook body'));
  }

  /// Signs [payload] the way the API does and returns the header value.
  /// Useful for testing your receiver.
  static String sign(
      {required String payload, required String secret, DateTime? timestamp}) {
    _checkSecret(secret);
    final seconds =
        (timestamp ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
    return 't=$seconds,v1=${_hmac(secret, '$seconds.$payload')}';
  }

  static void _checkSecret(String secret) {
    if (secret.trim().isEmpty) {
      throw ArgumentError.value(
          secret,
          'secret',
          'is empty. Anyone can sign with an empty key; '
              'set the subscription signing secret');
    }
  }

  static String _hmac(String secret, String message) =>
      Hmac(sha256, utf8.encode(secret))
          .convert(utf8.encode(message))
          .toString();

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
