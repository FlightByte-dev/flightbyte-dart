import '../json.dart';
import 'enums.dart';
import 'flight.dart';

/// A watched flight: the API polls it and posts a signed webhook to
/// [webhookUrl] whenever something about it changes.
final class Subscription {
  /// Creates a [Subscription].
  const Subscription({
    required this.id,
    required this.statusValue,
    required this.flightKey,
    required this.carrier,
    required this.flightNumber,
    required this.date,
    required this.webhookUrl,
    required this.secretHint,
    required this.eventValues,
    required this.delayThresholdMinutes,
    required this.createdAt,
    required this.updatedAt,
    this.headers,
    this.metadata,
    this.lastPolledAt,
    this.lastChangeAt,
    this.lastDeliveryAt,
    this.deliveredCount = 0,
    this.failedCount = 0,
    this.flightResolved = false,
    this.statusReason,
  });

  /// Decodes a [Subscription] from JSON.
  ///
  /// When the JSON carries the full `secret` (only the creation response does),
  /// [secretHint] is derived from it the way the API masks it.
  factory Subscription.fromJson(Json json) {
    final secret = optString(json, 'secret');
    return Subscription(
      id: reqString(json, 'id'),
      statusValue: reqString(json, 'status'),
      flightKey: reqString(json, 'flightKey'),
      carrier: reqString(json, 'carrier'),
      flightNumber: reqString(json, 'flightNumber'),
      date: reqString(json, 'date'),
      webhookUrl: reqString(json, 'webhookUrl'),
      secretHint: optString(json, 'secretHint') ??
          (secret == null ? '' : maskSecret(secret)),
      headers: optStringMap(json, 'headers'),
      eventValues: readStringList(json, 'events'),
      delayThresholdMinutes: optInt(json, 'delayThresholdMinutes') ?? 1,
      metadata: optStringMap(json, 'metadata'),
      createdAt: reqDate(json, 'createdAt'),
      updatedAt: reqDate(json, 'updatedAt'),
      lastPolledAt: optDate(json, 'lastPolledAt'),
      lastChangeAt: optDate(json, 'lastChangeAt'),
      lastDeliveryAt: optDate(json, 'lastDeliveryAt'),
      deliveredCount: optInt(json, 'deliveredCount') ?? 0,
      failedCount: optInt(json, 'failedCount') ?? 0,
      flightResolved: readBool(json, 'flightResolved'),
      statusReason: optString(json, 'statusReason'),
    );
  }

  /// Masks a signing secret the way the API does: the first 11 characters,
  /// `...`, and the last 4.
  static String maskSecret(String secret) => secret.length <= 15
      ? secret
      : '${secret.substring(0, 11)}...${secret.substring(secret.length - 4)}';

  /// Id, for example `sub_7Kd91mQx0Zb2c3d4e5f6`.
  final String id;

  /// The status as sent by the API.
  final String statusValue;

  /// Lifecycle status.
  SubscriptionStatus get status => SubscriptionStatus.fromValue(statusValue);

  /// The watched flight's key, for example `TK1848:2026-09-08`.
  final String flightKey;

  /// Carrier code.
  final String carrier;

  /// Flight number.
  final String flightNumber;

  /// Local departure date at the origin, `YYYY-MM-DD`.
  final String date;

  /// Where webhooks are posted.
  final String webhookUrl;

  /// The masked signing secret, for example `whsec_AbCdE...wxyz`.
  final String secretHint;

  /// Extra headers sent with every delivery.
  final Map<String, String>? headers;

  /// The change types as sent by the API.
  final List<String> eventValues;

  /// The change types that trigger a webhook.
  List<FlightChangeType> get events =>
      [for (final v in eventValues) FlightChangeType.fromValue(v)];

  /// Delay swings smaller than this many minutes are ignored.
  final int delayThresholdMinutes;

  /// Your own data, echoed back in every webhook.
  final Map<String, String>? metadata;

  /// When it was created.
  final DateTime createdAt;

  /// When it last changed.
  final DateTime updatedAt;

  /// When the flight was last polled.
  final DateTime? lastPolledAt;

  /// When a change was last detected.
  final DateTime? lastChangeAt;

  /// When a webhook was last delivered.
  final DateTime? lastDeliveryAt;

  /// Webhooks delivered.
  final int deliveredCount;

  /// Webhook attempts that failed.
  final int failedCount;

  /// `false` while the flight is not found upstream yet.
  final bool flightResolved;

  /// Why the subscription was suspended or completed.
  final String? statusReason;

  /// Encodes this value as JSON.
  Json toJson() => {
        'id': id,
        'status': statusValue,
        'flightKey': flightKey,
        'carrier': carrier,
        'flightNumber': flightNumber,
        'date': date,
        'webhookUrl': webhookUrl,
        'secretHint': secretHint,
        'headers': headers,
        'events': eventValues,
        'delayThresholdMinutes': delayThresholdMinutes,
        'metadata': metadata,
        'createdAt': isoOrNull(createdAt),
        'updatedAt': isoOrNull(updatedAt),
        'lastPolledAt': isoOrNull(lastPolledAt),
        'lastChangeAt': isoOrNull(lastChangeAt),
        'lastDeliveryAt': isoOrNull(lastDeliveryAt),
        'deliveredCount': deliveredCount,
        'failedCount': failedCount,
        'flightResolved': flightResolved,
        'statusReason': statusReason,
      };
}

/// The response of `subscriptions.create`.
final class CreatedSubscription {
  /// Creates a [CreatedSubscription].
  const CreatedSubscription({
    required this.subscription,
    required this.secret,
    required this.reused,
    this.flight,
  });

  /// Decodes a [CreatedSubscription] from JSON.
  factory CreatedSubscription.fromJson(Json json) => CreatedSubscription(
        subscription: Subscription.fromJson(json),
        secret: reqString(json, 'secret'),
        reused: readBool(json, 'reused'),
        flight: optObject(json, 'flight', FlightSnapshot.fromJson),
      );

  /// The subscription.
  final Subscription subscription;

  /// The full webhook signing secret. The API returns it in full only here
  /// (and from `subscriptions.secret`); store it where your webhook receiver
  /// can read it.
  final String secret;

  /// `true` when an earlier request with the same idempotency key (within 24
  /// hours) was replayed: the original subscription is returned and nothing new
  /// is created or billed.
  final bool reused;

  /// The flight as first seen, when it was found. Absent when [reused].
  final FlightSnapshot? flight;
}

/// One page of `subscriptions.list`.
final class SubscriptionPage {
  /// Creates a [SubscriptionPage].
  const SubscriptionPage({
    required this.total,
    required this.limit,
    required this.offset,
    required this.items,
  });

  /// Decodes a [SubscriptionPage] from JSON.
  factory SubscriptionPage.fromJson(Json json) {
    final items = readList(json, 'data', Subscription.fromJson);
    return SubscriptionPage(
      total: optInt(json, 'total') ?? items.length,
      limit: optInt(json, 'limit') ?? items.length,
      offset: optInt(json, 'offset') ?? 0,
      items: items,
    );
  }

  /// How many subscriptions match the filters.
  final int total;

  /// The page size used.
  final int limit;

  /// How many were skipped.
  final int offset;

  /// The subscriptions on this page.
  final List<Subscription> items;

  /// Whether more pages follow.
  bool get hasMore => offset + items.length < total;

  /// The offset of the next page.
  int get nextOffset => offset + items.length;
}

/// One webhook delivery attempt.
final class DeliveryRecord {
  /// Creates a [DeliveryRecord].
  const DeliveryRecord({
    required this.eventId,
    required this.attempt,
    required this.statusValue,
    required this.durationMs,
    required this.at,
    this.httpStatus,
    this.error,
    this.changeTypes = const [],
  });

  /// Decodes a [DeliveryRecord] from JSON.
  factory DeliveryRecord.fromJson(Json json) => DeliveryRecord(
        eventId: reqString(json, 'eventId'),
        attempt: optInt(json, 'attempt') ?? 1,
        statusValue: reqString(json, 'status'),
        httpStatus: optInt(json, 'httpStatus'),
        error: optString(json, 'error'),
        durationMs: optInt(json, 'durationMs') ?? 0,
        at: reqDate(json, 'at'),
        changeTypes: readStringList(json, 'changeTypes'),
      );

  /// The delivered event's id.
  final String eventId;

  /// Attempt number, starting at 1.
  final int attempt;

  /// The outcome as sent by the API.
  final String statusValue;

  /// The outcome.
  DeliveryStatus get status => DeliveryStatus.fromValue(statusValue);

  /// The receiver's HTTP status, when it answered.
  final int? httpStatus;

  /// What went wrong, when the attempt failed.
  final String? error;

  /// How long the attempt took.
  final int durationMs;

  /// When the attempt was made.
  final DateTime at;

  /// The change types the event carried.
  final List<String> changeTypes;

  /// Encodes this value as JSON.
  Json toJson() => {
        'eventId': eventId,
        'attempt': attempt,
        'status': statusValue,
        'httpStatus': httpStatus,
        'error': error,
        'durationMs': durationMs,
        'at': isoOrNull(at),
        'changeTypes': changeTypes,
      };
}
