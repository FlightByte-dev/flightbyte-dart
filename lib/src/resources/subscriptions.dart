import '../errors.dart';
import '../json.dart';
import '../models/enums.dart';
import '../models/subscription.dart';
import '../models/webhook_event.dart';
import '../transport.dart';

/// Watched flights and their webhooks. Reach it as `client.subscriptions`.
///
/// Every subscription is a billable watched flight.
final class SubscriptionsResource {
  /// Internal; use `FlightByteClient.subscriptions`.
  SubscriptionsResource(this._transport);

  final Transport _transport;

  /// Starts watching a flight. The API posts a signed webhook to [webhookUrl]
  /// each time something about it changes.
  ///
  /// - [date] is the local departure date at the origin, `YYYY-MM-DD`.
  /// - When the flight number operates several legs that day, pass [origin]
  ///   (or [flightId]); otherwise a [BadRequestException] lists the legs in
  ///   [BadRequestException.legs].
  /// - [secret] sets the webhook signing secret; by default the API generates
  ///   one, returned once in [CreatedSubscription.secret].
  /// - [events] filters the change types; by default every type is sent.
  /// - [delayThresholdMinutes] (1–240) ignores smaller delay swings.
  /// - [headers] are added to every delivery; [metadata] is echoed back in
  ///   every webhook.
  /// - With [idempotencyKey], repeating the request within 24 hours returns the
  ///   original subscription with [CreatedSubscription.reused] set, instead of
  ///   creating and billing a second one. Use it for retries.
  ///
  /// Throws [PaymentRequiredException] when the period's watched flights are
  /// used up.
  Future<CreatedSubscription> create({
    required String carrier,
    required String flightNumber,
    required String date,
    required Uri webhookUrl,
    String? origin,
    String? destination,
    String? flightId,
    String? secret,
    List<FlightChangeType>? events,
    int? delayThresholdMinutes,
    Map<String, String>? headers,
    Map<String, String>? metadata,
    String? idempotencyKey,
  }) async {
    final body = await _transport.send(
      'POST',
      ['subscriptions'],
      body: {
        'carrier': carrier,
        'flightNumber': flightNumber,
        'date': date,
        'webhookUrl': webhookUrl.toString(),
        if (origin != null) 'origin': origin,
        if (destination != null) 'destination': destination,
        if (flightId != null) 'flightId': flightId,
        if (secret != null) 'secret': secret,
        if (events != null) 'events': _eventValues(events),
        if (delayThresholdMinutes != null)
          'delayThresholdMinutes': delayThresholdMinutes,
        if (headers != null) 'headers': headers,
        if (metadata != null) 'metadata': metadata,
      },
      headers: {if (idempotencyKey != null) 'idempotency-key': idempotencyKey},
    );
    return CreatedSubscription.fromJson(asJson(body, 'the subscription'));
  }

  /// One page of your subscriptions, newest first. [limit] is clamped by the
  /// API to 1–200 (default 25).
  Future<SubscriptionPage> list({
    SubscriptionStatus? status,
    String? carrier,
    String? flightNumber,
    String? date,
    int? limit,
    int? offset,
  }) async {
    final body = await _transport.send(
      'GET',
      ['subscriptions'],
      query: {
        'status': status?.value,
        'carrier': carrier,
        'flightNumber': flightNumber,
        'date': date,
        'limit': limit,
        'offset': offset,
      },
    );
    return SubscriptionPage.fromJson(asJson(body, 'the subscription list'));
  }

  /// Every subscription matching the filters, fetched page by page.
  Stream<Subscription> listAll({
    SubscriptionStatus? status,
    String? carrier,
    String? flightNumber,
    String? date,
    int pageSize = 200,
  }) async* {
    var offset = 0;
    while (true) {
      final page = await list(
        status: status,
        carrier: carrier,
        flightNumber: flightNumber,
        date: date,
        limit: pageSize,
        offset: offset,
      );
      yield* Stream.fromIterable(page.items);
      if (!page.hasMore || page.items.isEmpty) return;
      offset = page.nextOffset;
    }
  }

  /// One subscription. Throws [NotFoundException] when it does not exist or
  /// belongs to another key.
  Future<Subscription> get(String id) async =>
      _subscription(await _transport.send('GET', ['subscriptions', id]));

  /// Changes a subscription. Only the fields you pass are changed.
  ///
  /// [headers] and [metadata] replace the existing maps; the API cannot clear
  /// them, so an empty map leaves them as they are.
  Future<Subscription> update(
    String id, {
    Uri? webhookUrl,
    List<FlightChangeType>? events,
    int? delayThresholdMinutes,
    Map<String, String>? headers,
    Map<String, String>? metadata,
  }) async {
    final body = await _transport.send(
      'PATCH',
      ['subscriptions', id],
      body: {
        if (webhookUrl != null) 'webhookUrl': webhookUrl.toString(),
        if (events != null) 'events': _eventValues(events),
        if (delayThresholdMinutes != null)
          'delayThresholdMinutes': delayThresholdMinutes,
        if (headers != null) 'headers': headers,
        if (metadata != null) 'metadata': metadata,
      },
    );
    return _subscription(body);
  }

  /// Stops watching the flight and deletes the subscription.
  Future<void> delete(String id) async {
    await _transport.send('DELETE', ['subscriptions', id]);
  }

  /// Pauses polling and deliveries; [resume] picks up where it left off.
  Future<Subscription> pause(String id) async => _subscription(
      await _transport.send('POST', ['subscriptions', id, 'pause']));

  /// Resumes a paused or suspended subscription. A completed one cannot be
  /// resumed and gives a [BadRequestException].
  Future<Subscription> resume(String id) async => _subscription(
      await _transport.send('POST', ['subscriptions', id, 'resume']));

  /// Sends a `subscription.test` webhook and returns its event id.
  Future<String> sendTest(String id) async {
    final body = await _transport.send('POST', ['subscriptions', id, 'test']);
    return reqString(asJson(body, 'the test result'), 'eventId');
  }

  /// The latest delivery attempts, newest first. [limit] is 1–100 (default 25).
  Future<List<DeliveryRecord>> deliveries(String id, {int? limit}) async {
    final body = await _transport.send(
      'GET',
      ['subscriptions', id, 'deliveries'],
      query: {'limit': limit},
    );
    return readList(
        asJson(body, 'the delivery list'), 'data', DeliveryRecord.fromJson);
  }

  /// The latest events, as they were posted, newest first. [limit] is 1–100
  /// (default 25).
  Future<List<WebhookEvent>> events(String id, {int? limit}) async {
    final body = await _transport.send(
      'GET',
      ['subscriptions', id, 'events'],
      query: {'limit': limit},
    );
    return readList(
        asJson(body, 'the event list'), 'data', WebhookEvent.fromJson);
  }

  /// The full webhook signing secret.
  Future<String> secret(String id) async {
    final body = await _transport.send('GET', ['subscriptions', id, 'secret']);
    return reqString(asJson(body, 'the secret'), 'secret');
  }

  /// Replaces the webhook signing secret and returns the new one. Deliveries
  /// are signed with the new secret from now on, so update your receiver
  /// right away.
  Future<String> rotateSecret(String id) async {
    final body = await _transport
        .send('POST', ['subscriptions', id, 'secret', 'rotate']);
    return reqString(asJson(body, 'the secret'), 'secret');
  }

  Subscription _subscription(Object? body) =>
      Subscription.fromJson(asJson(body, 'the subscription'));

  List<String> _eventValues(List<FlightChangeType> events) {
    if (events.contains(FlightChangeType.unknown)) {
      throw ArgumentError.value(
          events, 'events', 'FlightChangeType.unknown cannot be sent');
    }
    return [for (final e in events) e.value];
  }
}
