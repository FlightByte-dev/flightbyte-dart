import 'package:http/http.dart' as http;

import 'rate_limit.dart';
import 'resources/countries.dart';
import 'resources/flights.dart';
import 'resources/subscriptions.dart';
import 'transport.dart';

/// A client for the FlightByte API.
///
/// ```dart
/// final client = FlightByteClient(apiKey: 'frk_live_...');
/// final flight = await client.flights.get(
///   carrier: 'TK',
///   flightNumber: '1848',
///   date: '2026-09-08',
/// );
/// print(flight.status.label);
/// client.close();
/// ```
///
/// Keep API keys on a server you control. A key shipped inside a mobile or
/// web app can be extracted by anyone who has the app.
final class FlightByteClient {
  /// Creates a client.
  ///
  /// - [baseUrl] defaults to [defaultBaseUrl]; point it at a local API with,
  ///   for example, `Uri.parse('http://localhost:3000/v1')`.
  /// - [httpClient] lets you bring your own `http.Client` (for retries,
  ///   logging or tests). A client you pass is not closed by [close].
  /// - [timeout] bounds each request, response body included.
  FlightByteClient({
    required String apiKey,
    Uri? baseUrl,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 30),
  }) : _transport = Transport(
          apiKey: _checkKey(apiKey),
          baseUrl: baseUrl ?? defaultBaseUrl,
          httpClient: httpClient ?? http.Client(),
          timeout: timeout,
          ownsClient: httpClient == null,
        );

  static String _checkKey(String apiKey) {
    if (apiKey.trim().isEmpty) {
      throw ArgumentError.value(apiKey, 'apiKey', 'must not be empty');
    }
    return apiKey.trim();
  }

  /// The production API root.
  static final Uri defaultBaseUrl = Uri.parse('https://api.flightbyte.dev/v1');

  /// Formats [date] as the `YYYY-MM-DD` the API expects for flight dates.
  ///
  /// Only the calendar fields are used, so pass the local departure date at
  /// the origin airport, not a UTC instant converted from somewhere else.
  static String formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  final Transport _transport;

  /// Flight lookups.
  late final FlightsResource flights = FlightsResource(_transport);

  /// Watched flights and their webhooks.
  late final SubscriptionsResource subscriptions =
      SubscriptionsResource(_transport);

  /// Countries and flags.
  late final CountriesResource countries = CountriesResource(_transport);

  /// The API root this client talks to.
  Uri get baseUrl => _transport.baseUrl;

  /// The quota state from the latest response that reported one.
  RateLimitInfo? get lastRateLimit => _transport.lastRateLimit;

  /// Releases the HTTP client, when this client created it.
  void close() => _transport.close();
}
