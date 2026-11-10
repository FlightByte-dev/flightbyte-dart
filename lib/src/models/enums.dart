/// Enumerations used across the API.
///
/// Every enum has an `unknown` member. A value the API adds after this package
/// was released decodes to `unknown` instead of throwing, and the models keep
/// the raw string next to the enum so nothing is lost.
library;

/// Coarse lifecycle bucket of a flight.
enum FlightPhase implements _WireValue {
  /// Not departed yet.
  scheduled('scheduled'),

  /// Boarding at the gate.
  boarding('boarding'),

  /// Left the gate.
  departed('departed'),

  /// Airborne.
  enRoute('en_route'),

  /// Touched down.
  landed('landed'),

  /// At the arrival gate.
  arrived('arrived'),

  /// Cancelled.
  cancelled('cancelled'),

  /// Diverted to another airport.
  diverted('diverted'),

  /// Redirected.
  redirected('redirected'),

  /// Unknown to the API, or a value newer than this package.
  unknown('unknown');

  const FlightPhase(this.value);

  /// The wire value.
  @override
  final String value;

  /// Whether the flight is finished: arrived, cancelled, diverted or redirected.
  bool get isTerminal =>
      this == arrived ||
      this == cancelled ||
      this == diverted ||
      this == redirected;

  /// Decodes [value], falling back to [unknown].
  static FlightPhase fromValue(String? value) =>
      _decode(values, value, unknown);
}

/// Lifecycle of a subscription.
enum SubscriptionStatus implements _WireValue {
  /// Polling the flight and delivering webhooks.
  active('active'),

  /// Accepted, but the flight is not published upstream yet.
  pending('pending'),

  /// Paused by you; nothing is polled or delivered.
  paused('paused'),

  /// The flight finished and the grace window passed.
  completed('completed'),

  /// Disabled by the API, for example after repeated delivery failures.
  suspended('suspended'),

  /// A value newer than this package.
  unknown('unknown');

  const SubscriptionStatus(this.value);

  /// The wire value.
  @override
  final String value;

  /// Decodes [value], falling back to [unknown].
  static SubscriptionStatus fromValue(String? value) =>
      _decode(values, value, unknown);
}

/// The kind of change a `flight.updated` webhook reports, and the filter a
/// subscription's `events` list is made of.
enum FlightChangeType implements _WireValue {
  /// The upstream status code changed.
  statusChanged('status.changed'),

  /// The flight left the gate.
  departed('flight.departed'),

  /// The flight arrived.
  arrived('flight.arrived'),

  /// The flight was cancelled.
  cancelled('flight.cancelled'),

  /// The flight was diverted.
  diverted('flight.diverted'),

  /// A cancelled flight was reinstated.
  reinstated('flight.reinstated'),

  /// The departure gate changed.
  departureGateChanged('departure.gate.changed'),

  /// The departure terminal changed.
  departureTerminalChanged('departure.terminal.changed'),

  /// The arrival gate changed.
  arrivalGateChanged('arrival.gate.changed'),

  /// The arrival terminal changed.
  arrivalTerminalChanged('arrival.terminal.changed'),

  /// The baggage carousel changed.
  baggageChanged('arrival.baggage.changed'),

  /// The scheduled departure time changed.
  departureScheduleChanged('departure.scheduled.changed'),

  /// The estimated departure time changed.
  departureEstimateChanged('departure.estimated.changed'),

  /// The actual departure time changed.
  departureActualChanged('departure.actual.changed'),

  /// The scheduled arrival time changed.
  arrivalScheduleChanged('arrival.scheduled.changed'),

  /// The estimated arrival time changed.
  arrivalEstimateChanged('arrival.estimated.changed'),

  /// The actual arrival time changed.
  arrivalActualChanged('arrival.actual.changed'),

  /// The delay grew.
  delayIncreased('delay.increased'),

  /// The delay shrank.
  delayDecreased('delay.decreased'),

  /// The aircraft type changed.
  aircraftChanged('aircraft.changed'),

  /// The tail number changed.
  tailNumberChanged('aircraft.tail.changed'),

  /// The route changed.
  routeChanged('route.changed'),

  /// The codeshare list changed.
  codesharesChanged('codeshares.changed'),

  /// A value newer than this package.
  unknown('unknown');

  const FlightChangeType(this.value);

  /// The wire value.
  @override
  final String value;

  /// Decodes [value], falling back to [unknown].
  static FlightChangeType fromValue(String? value) =>
      _decode(values, value, unknown);
}

/// The type of a webhook event.
enum WebhookEventType implements _WireValue {
  /// The subscription was created.
  subscriptionCreated('subscription.created'),

  /// A pending subscription found its flight and started polling.
  subscriptionActivated('subscription.activated'),

  /// A test event sent with `subscriptions.sendTest`.
  subscriptionTest('subscription.test'),

  /// The flight finished and the subscription completed.
  subscriptionCompleted('subscription.completed'),

  /// The subscription was suspended.
  subscriptionSuspended('subscription.suspended'),

  /// Something about the flight changed; see the event's `changes`.
  flightUpdated('flight.updated'),

  /// A value newer than this package.
  unknown('unknown');

  const WebhookEventType(this.value);

  /// The wire value.
  @override
  final String value;

  /// Decodes [value], falling back to [unknown].
  static WebhookEventType fromValue(String? value) =>
      _decode(values, value, unknown);
}

/// Outcome of one webhook delivery attempt.
enum DeliveryStatus implements _WireValue {
  /// The receiver answered 2xx.
  delivered('delivered'),

  /// The attempt failed.
  failed('failed'),

  /// A value newer than this package.
  unknown('unknown');

  const DeliveryStatus(this.value);

  /// The wire value.
  @override
  final String value;

  /// Decodes [value], falling back to [unknown].
  static DeliveryStatus fromValue(String? value) =>
      _decode(values, value, unknown);
}

abstract interface class _WireValue {
  String get value;
}

T _decode<T extends _WireValue>(List<T> values, String? value, T fallback) {
  for (final candidate in values) {
    if (candidate.value == value) return candidate;
  }
  return fallback;
}
