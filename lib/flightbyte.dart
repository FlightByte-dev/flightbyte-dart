/// Official Dart client for the FlightByte flight status API.
///
/// - [FlightByteClient] looks flights up and manages subscriptions.
/// - [Webhook] verifies and decodes the signed webhooks the API posts.
/// - Every request error is a [FlightByteException].
library;

export 'src/client.dart' show FlightByteClient;
export 'src/errors.dart';
export 'src/models/country.dart';
export 'src/models/enums.dart';
export 'src/models/flight.dart';
export 'src/models/subscription.dart';
export 'src/models/webhook_event.dart';
export 'src/rate_limit.dart';
export 'src/resources/countries.dart' show CountriesResource;
export 'src/resources/flights.dart' show FlightsResource;
export 'src/resources/subscriptions.dart' show SubscriptionsResource;
export 'src/version.dart' show packageVersion;
export 'src/webhook.dart';
