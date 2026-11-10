# flightbyte

Official Dart client for the [FlightByte](https://flightbyte.dev) flight status API.

- Look a flight up by carrier, flight number and date.
- Subscribe to a flight and get a signed webhook each time something about it changes: gate, terminal, delay, departure, arrival, cancellation and more.
- Verify and decode those webhooks on your Dart server.

Pure Dart: it works in Flutter apps, on Dart servers (shelf, dart_frog) and in CLI tools.

## Install

```sh
dart pub add flightbyte
```

or, in a Flutter app:

```sh
flutter pub add flightbyte
```

## Look a flight up

```dart
import 'package:flightbyte/flightbyte.dart';

final client = FlightByteClient(apiKey: 'frk_live_...');

final flight = await client.flights.get(
  carrier: 'TK',
  flightNumber: '1848',
  date: '2026-09-08', // local departure date at the origin
);

print(flight.status.label);                     // Scheduled
print(flight.departure.gate);                   // A11
print(flight.departure.times.bestGate?.local);  // 2026-09-08T12:25:00.000
print(flight.departure.delayMinutes);           // 15

client.close();
```

A flight number can operate several legs on one date (TK1 can be both SAW-AMS and IST-JFK). Every leg is listed in `flight.alternates`; pass `origin:` (and optionally `destination:`) to choose one.

`FlightByteClient.formatDate(DateTime)` turns a date into the `YYYY-MM-DD` the API expects.

## Watch a flight

```dart
final created = await client.subscriptions.create(
  carrier: 'TK',
  flightNumber: '1848',
  date: '2026-09-08',
  webhookUrl: Uri.parse('https://example.com/hooks/flights'),
  events: [
    FlightChangeType.departureGateChanged,
    FlightChangeType.delayIncreased,
    FlightChangeType.departed,
  ],
  metadata: {'booking': '42'},
  idempotencyKey: 'booking-42', // safe to retry
);

// Shown in full only now: store it where your webhook receiver can read it.
final signingSecret = created.secret;
```

Each subscription is a billable watched flight. Manage them with `list`, `listAll`, `get`, `update`, `pause`, `resume`, `delete`, `sendTest`, `deliveries`, `events`, `secret` and `rotateSecret` on `client.subscriptions`.

## Receive webhooks

Verify every delivery against the raw body before trusting it. With [shelf](https://pub.dev/packages/shelf):

```dart
import 'package:flightbyte/flightbyte.dart';
import 'package:shelf/shelf.dart';

Future<Response> flightHook(Request request) async {
  final payload = await request.readAsString();
  final WebhookEvent event;
  try {
    event = Webhook.constructEvent(
      payload: payload,
      signature: request.headers[Webhook.signatureHeader],
      secret: signingSecret,
    );
  } on WebhookSignatureException {
    return Response.badRequest();
  }

  // event.id is the same across retries: deduplicate on it.
  if (event.type == WebhookEventType.flightUpdated) {
    for (final change in event.changes) {
      print('${event.flightKey}: ${change.message}');
    }
  }
  return Response.ok('ok');
}
```

Answer 2xx quickly. Failed deliveries are retried with backoff. A 4xx other than 408 or 429 is not retried.

## Errors

Every failed request throws a subclass of the sealed `FlightByteException`, so a `switch` over it is checked for completeness:

| Exception | When |
|---|---|
| `BadRequestException` | Invalid input. For an ambiguous flight number, `legs` lists the legs to choose from. |
| `AuthenticationException` | Missing, invalid or revoked API key. |
| `PaymentRequiredException` | No watched flights left this period (`code`, `limit`, `used`, `resetsAt`). |
| `PermissionDeniedException` | Account suspended, or missing scope (`code`). |
| `NotFoundException` | The flight did not operate, or no such subscription. |
| `RateLimitException` | Quota used up; wait `retryAfter`. |
| `UpstreamException` | The flight data provider failed; retry shortly. |
| `ServerException`, `UnexpectedStatusException` | Anything else. |
| `FlightByteConnectionException` | No response: network error or timeout. |

```dart
try {
  await client.flights.get(carrier: 'TK', flightNumber: '1', date: '2026-09-08');
} on BadRequestException catch (e) {
  for (final leg in e.legs) {
    print('Try origin: ${leg.origin}');
  }
} on RateLimitException catch (e) {
  await Future<void>.delayed(e.retryAfter ?? const Duration(seconds: 5));
}
```

`client.lastRateLimit` holds the quota state from the latest response.

## Keep your keys on a server

An API key or webhook secret shipped inside a mobile or web app can be pulled out of it by anyone. In a Flutter app, call your own backend, and have the backend use this package with the key. Flag images are the exception: `client.countries.flagUrl('TR')` needs no key and can go straight into an image widget.

## Configuration

```dart
FlightByteClient(
  apiKey: 'frk_test_...',
  baseUrl: Uri.parse('http://localhost:3000/v1'), // default: https://api.flightbyte.dev/v1
  httpClient: myClient,                           // bring your own http.Client
  timeout: const Duration(seconds: 10),           // default: 30 seconds
);
```

Values the API adds after this package was released decode to `unknown` enum members instead of throwing. The raw string is kept, for example in `FlightChange.typeValue`.

## Links

- API reference: https://api.flightbyte.dev/docs
- Website: https://flightbyte.dev
