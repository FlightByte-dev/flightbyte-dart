import 'dart:convert';

import 'json.dart';

/// Base class of every error this package throws for a failed request.
///
/// It is `sealed`, so a `switch` over it is checked for exhaustiveness:
///
/// ```dart
/// try {
///   await client.flights.get(carrier: 'TK', flightNumber: '1848', date: '2026-09-08');
/// } on FlightByteException catch (e) {
///   switch (e) {
///     case NotFoundException():
///       print('No such flight');
///     case RateLimitException(:final retryAfter):
///       print('Slow down, retry in $retryAfter');
///     default:
///       print(e);
///   }
/// }
/// ```
sealed class FlightByteException implements Exception {
  const FlightByteException(this.message);

  /// What went wrong.
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// The request never got an HTTP response: no network, DNS failure, a refused
/// connection or a timeout.
final class FlightByteConnectionException extends FlightByteException {
  /// Creates a [FlightByteConnectionException].
  const FlightByteConnectionException(super.message, {this.cause});

  /// The underlying error.
  final Object? cause;
}

/// The API answered with an error status.
///
/// The fields mirror the API's error body:
/// `{statusCode, error, message, path, timestamp, requestId, ...}`.
sealed class FlightByteApiException extends FlightByteException {
  FlightByteApiException._(
      this.statusCode, this.body, this.rawBody, this.headers)
      : messages = _messages(body),
        super(_summary(statusCode, body, headers));

  /// Builds the subclass matching [statusCode] from a raw response.
  factory FlightByteApiException.fromResponse(
    int statusCode,
    String rawBody,
    Map<String, String> headers,
  ) {
    final body = _decode(rawBody);
    return switch (statusCode) {
      400 => BadRequestException._(statusCode, body, rawBody, headers),
      401 => AuthenticationException._(statusCode, body, rawBody, headers),
      402 => PaymentRequiredException._(statusCode, body, rawBody, headers),
      403 => PermissionDeniedException._(statusCode, body, rawBody, headers),
      404 => NotFoundException._(statusCode, body, rawBody, headers),
      429 => RateLimitException._(statusCode, body, rawBody, headers),
      502 => UpstreamException._(statusCode, body, rawBody, headers),
      _ when statusCode >= 500 =>
        ServerException._(statusCode, body, rawBody, headers),
      _ => UnexpectedStatusException._(statusCode, body, rawBody, headers),
    };
  }

  /// HTTP status code.
  final int statusCode;

  /// The decoded error body; empty when the body was not a JSON object.
  final Json body;

  /// The body exactly as received.
  final String rawBody;

  /// Response headers, lower-cased.
  final Map<String, String> headers;

  /// Every message the API sent. Validation errors send one per field.
  final List<String> messages;

  /// Nest's error phrase, for example `Bad Request`. Not a stable code; branch
  /// on the exception type and [code] instead.
  String? get error => _string(body['error']);

  /// A machine-readable reason, when the API sends one, for example
  /// `watched_flight_limit` or `account_suspended`.
  String? get code => _string(body['code']);

  /// The request id; quote it when contacting support.
  String? get requestId =>
      _string(body['requestId']) ?? headers['x-request-id'];

  @override
  String toString() {
    final id = requestId == null ? '' : ' (request $requestId)';
    return '$runtimeType [$statusCode]: $message$id';
  }
}

/// 400: the request was invalid.
final class BadRequestException extends FlightByteApiException {
  BadRequestException._(
      super.statusCode, super.body, super.rawBody, super.headers)
      : super._();

  /// When a flight number operates several legs on the date and no `origin`
  /// was given, the legs to choose from. Pass one's [AmbiguousLeg.origin] (or
  /// [AmbiguousLeg.flightId]) and try again.
  List<AmbiguousLeg> get legs {
    final value = body['legs'];
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (item is Map) AmbiguousLeg._(asJson(item)),
    ];
  }
}

/// One of the legs listed by an ambiguous-flight [BadRequestException].
final class AmbiguousLeg {
  AmbiguousLeg._(Json json)
      : origin = _string(json['origin']) ?? '',
        destination = _string(json['destination']) ?? '',
        carrier = _string(json['carrier']),
        scheduledDepartureLocal = _string(json['scheduledDepartureLocal']),
        flightId = _string(json['flightId']);

  /// Origin IATA code.
  final String origin;

  /// Destination IATA code.
  final String destination;

  /// Operating carrier.
  final String? carrier;

  /// Scheduled local departure, `HH:mm`.
  final String? scheduledDepartureLocal;

  /// Upstream flight id.
  final String? flightId;

  @override
  String toString() => '$origin-$destination'
      '${scheduledDepartureLocal == null ? '' : ' $scheduledDepartureLocal'}';
}

/// 401: the API key is missing, invalid or revoked.
final class AuthenticationException extends FlightByteApiException {
  AuthenticationException._(
      super.statusCode, super.body, super.rawBody, super.headers)
      : super._();
}

/// 402: no watched flights can be created.
///
/// [code] is `watched_flight_limit` (the plan's cap), `overage_cap_reached`
/// (the account's overage cap) or `credits_exhausted` (prepaid credits used
/// up).
final class PaymentRequiredException extends FlightByteApiException {
  PaymentRequiredException._(
      super.statusCode, super.body, super.rawBody, super.headers)
      : super._();

  /// Watched flights the period allows. Not with `credits_exhausted`.
  int? get limit => _int(body['limit']);

  /// Watched flights created this period. Not with `credits_exhausted`.
  int? get used => _int(body['used']);

  /// When the period, and so the count, resets. Not with `credits_exhausted`.
  DateTime? get resetsAt => _date(body['resetsAt']);

  /// The overage cap in US cents, with `overage_cap_reached`.
  int? get capCents => _int(body['capCents']);

  /// Prepaid credits left, with `credits_exhausted`.
  int? get balance => _int(body['balance']);

  /// When the prepaid credits expire or expired, 12 months after the last
  /// top-up, with `credits_exhausted`. Null when the API sends none.
  DateTime? get expiresAt => _date(body['expiresAt']);
}

/// 403: the account is suspended (`code: account_suspended`) or an OAuth token
/// lacks the scope (`code: insufficient_scope`).
final class PermissionDeniedException extends FlightByteApiException {
  PermissionDeniedException._(
      super.statusCode, super.body, super.rawBody, super.headers)
      : super._();
}

/// 404: the flight did not operate, or the subscription does not exist (or
/// belongs to another key).
final class NotFoundException extends FlightByteApiException {
  NotFoundException._(
      super.statusCode, super.body, super.rawBody, super.headers)
      : super._();
}

/// 429: a minute, day or month quota is used up.
final class RateLimitException extends FlightByteApiException {
  RateLimitException._(
      super.statusCode, super.body, super.rawBody, super.headers)
      : super._();

  /// The window that ran out: `minute`, `day` or `month`.
  String? get window => _string(body['window']);

  /// How long to wait before retrying.
  Duration? get retryAfter {
    final seconds = _int(body['retryAfterSeconds']) ??
        int.tryParse(headers['retry-after'] ?? '');
    return seconds == null ? null : Duration(seconds: seconds);
  }
}

/// 502: the upstream flight data provider failed or is temporarily cut off.
/// Safe to retry after a short wait.
final class UpstreamException extends FlightByteApiException {
  UpstreamException._(
      super.statusCode, super.body, super.rawBody, super.headers)
      : super._();
}

/// Any other 5xx.
final class ServerException extends FlightByteApiException {
  ServerException._(super.statusCode, super.body, super.rawBody, super.headers)
      : super._();
}

/// A non-2xx status this package does not map to a type of its own.
///
/// This includes a redirect the client refused to follow because it pointed
/// at another scheme, host or port; `headers['location']` says where.
final class UnexpectedStatusException extends FlightByteApiException {
  UnexpectedStatusException._(
      super.statusCode, super.body, super.rawBody, super.headers)
      : super._();
}

Json _decode(String rawBody) {
  if (rawBody.isEmpty) return const {};
  try {
    final decoded = jsonDecode(rawBody);
    return decoded is Map ? asJson(decoded) : const {};
  } on FormatException {
    return const {};
  }
}

String _summary(int statusCode, Json body, Map<String, String> headers) {
  final joined = _messages(body).join(' ');
  if (joined.isNotEmpty) return joined;
  final location = headers['location'];
  if (statusCode >= 300 && statusCode < 400 && location != null) {
    return 'HTTP $statusCode redirect to $location was not followed, so the '
        'API key was not sent there.';
  }
  return 'HTTP $statusCode';
}

List<String> _messages(Json body) {
  final message = body['message'];
  if (message is String) return [message];
  if (message is List) return [for (final m in message) '$m'];
  return const [];
}

String? _string(Object? value) => value is String ? value : null;

int? _int(Object? value) => value is num ? value.toInt() : null;

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
