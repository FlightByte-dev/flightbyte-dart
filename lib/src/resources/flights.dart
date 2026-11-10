import '../errors.dart';
import '../json.dart';
import '../models/flight.dart';
import '../transport.dart';

/// Flight lookups. Reach it as `client.flights`.
final class FlightsResource {
  /// Internal; use `FlightByteClient.flights`.
  FlightsResource(this._transport);

  final Transport _transport;

  /// Looks a flight up.
  ///
  /// [date] is the local departure date at the origin, `YYYY-MM-DD`; see
  /// `FlightByteClient.formatDate`. The API normalizes [carrier] to upper case
  /// and strips leading zeros from [flightNumber].
  ///
  /// A flight number can operate several legs on one date. The snapshot lists
  /// them all in [FlightSnapshot.alternates]; pass [origin] (and optionally
  /// [destination]) or a leg's [flightId] to choose one. With [refresh] the
  /// API skips its cache and asks upstream.
  ///
  /// Throws [NotFoundException] when the flight did not operate that day.
  Future<FlightSnapshot> get({
    required String carrier,
    required String flightNumber,
    required String date,
    String? origin,
    String? destination,
    String? flightId,
    bool refresh = false,
  }) async {
    final body = await _transport.send(
      'GET',
      ['flights', carrier, flightNumber, date],
      query: {
        'origin': origin,
        'destination': destination,
        'flightId': flightId,
        if (refresh) 'refresh': 'true',
      },
    );
    return FlightSnapshot.fromJson(asJson(body, 'the flight'));
  }

  /// The flight's change history as recorded by the API, newest first.
  Future<FlightTimeline> timeline({
    required String carrier,
    required String flightNumber,
    required String date,
    String? origin,
    String? destination,
  }) async {
    final body = await _transport.send(
      'GET',
      ['flights', carrier, flightNumber, date, 'timeline'],
      query: {'origin': origin, 'destination': destination},
    );
    return FlightTimeline.fromJson(asJson(body, 'the timeline'));
  }
}
