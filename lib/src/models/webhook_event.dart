import '../json.dart';
import 'enums.dart';
import 'flight.dart';

/// One change inside a `flight.updated` event.
final class FlightChange {
  /// Creates a [FlightChange].
  const FlightChange({
    required this.typeValue,
    required this.path,
    required this.message,
    this.from,
    this.to,
    this.deltaMinutes,
  });

  /// Decodes a [FlightChange] from JSON.
  factory FlightChange.fromJson(Json json) => FlightChange(
        typeValue: reqString(json, 'type'),
        path: reqString(json, 'path'),
        from: _scalar(json, 'from'),
        to: _scalar(json, 'to'),
        message: reqString(json, 'message'),
        deltaMinutes: optInt(json, 'deltaMinutes'),
      );

  /// The type as sent by the API.
  final String typeValue;

  /// What changed.
  FlightChangeType get type => FlightChangeType.fromValue(typeValue);

  /// Dotted path into the snapshot, for example `departure.gate`.
  final String path;

  /// The old value: a string, a number or `null`. Times are ISO-8601 UTC strings.
  final Object? from;

  /// The new value: a string, a number or `null`. Times are ISO-8601 UTC strings.
  final Object? to;

  /// A sentence describing the change.
  final String message;

  /// Signed minute delta, for time changes.
  final int? deltaMinutes;

  /// Encodes this value as JSON.
  Json toJson() => {
        'type': typeValue,
        'path': path,
        'from': from,
        'to': to,
        'message': message,
        'deltaMinutes': deltaMinutes,
      };
}

/// A webhook event, as posted to your receiver and as listed by
/// `subscriptions.events`.
final class WebhookEvent {
  /// Creates a [WebhookEvent].
  const WebhookEvent({
    required this.id,
    required this.typeValue,
    required this.createdAt,
    required this.subscriptionId,
    required this.flightKey,
    this.flight,
    this.changes = const [],
    this.previousFetchedAt,
    this.metadata,
  });

  /// Decodes a [WebhookEvent] from JSON.
  factory WebhookEvent.fromJson(Json json) => WebhookEvent(
        id: reqString(json, 'id'),
        typeValue: reqString(json, 'type'),
        createdAt: reqDate(json, 'createdAt'),
        subscriptionId: reqString(json, 'subscriptionId'),
        flightKey: reqString(json, 'flightKey'),
        flight: optObject(json, 'flight', FlightSnapshot.fromJson),
        changes: readList(json, 'changes', FlightChange.fromJson),
        previousFetchedAt: optDate(json, 'previousFetchedAt'),
        metadata: optStringMap(json, 'metadata'),
      );

  /// Event id, `evt_<uuid>`. The same across delivery retries: deduplicate on it.
  final String id;

  /// The type as sent by the API.
  final String typeValue;

  /// The event type.
  WebhookEventType get type => WebhookEventType.fromValue(typeValue);

  /// When the event was created.
  final DateTime createdAt;

  /// The subscription it belongs to.
  final String subscriptionId;

  /// The flight's key.
  final String flightKey;

  /// The flight after the change. Missing on some lifecycle events.
  final FlightSnapshot? flight;

  /// What changed. Empty except on `flight.updated`.
  final List<FlightChange> changes;

  /// When the previous snapshot was fetched, on `flight.updated`.
  final DateTime? previousFetchedAt;

  /// The subscription's metadata.
  final Map<String, String>? metadata;

  /// Encodes this value as JSON.
  Json toJson() => {
        'id': id,
        'type': typeValue,
        'createdAt': isoOrNull(createdAt),
        'subscriptionId': subscriptionId,
        'flightKey': flightKey,
        if (flight != null) 'flight': flight!.toJson(),
        'changes': [for (final c in changes) c.toJson()],
        'previousFetchedAt': isoOrNull(previousFetchedAt),
        'metadata': metadata,
      };
}

Object? _scalar(Json json, String key) {
  final value = json[key];
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  throw FormatException('Expected "$key" to be a string, number or null.');
}
