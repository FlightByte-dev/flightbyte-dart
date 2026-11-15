<p align="center">
  <a href="https://flightbyte.dev">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="assets/logo-dark.svg">
      <img src="assets/logo-light.svg" alt="FlightByte" width="340">
    </picture>
  </a>
</p>

<h3 align="center">FlightByte for Dart and Flutter</h3>

<p align="center">
  The official Dart client for the FlightByte flight status API.<br>
  Look flights up, watch them with signed webhooks and verify every delivery,<br>
  from a Dart server, a CLI or the backend behind your Flutter app.
</p>

<p align="center">
  <a href="https://pub.dev/packages/flightbyte"><img src="https://img.shields.io/pub/v/flightbyte?style=flat-square&color=EF6A1A&label=pub" alt="pub version"></a>
  <img src="https://img.shields.io/badge/Dart-3.5%2B-121212?style=flat-square&logo=dart&logoColor=white" alt="Dart 3.5+">
  <img src="https://img.shields.io/badge/Flutter-iOS_%7C_Android_%7C_web_%7C_desktop-121212?style=flat-square&logo=flutter&logoColor=white" alt="Flutter on every platform">
  <img src="https://img.shields.io/badge/dependencies-http_%7C_crypto-EF6A1A?style=flat-square" alt="Dependencies: http and crypto">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-121212?style=flat-square" alt="MIT license"></a>
</p>

<p align="center">
  <a href="https://flightbyte.dev/docs"><b>Docs</b></a> ·
  <a href="https://app.flightbyte.dev/signup?utm_source=pub.dev&utm_medium=readme&utm_campaign=dart-sdk"><b>Get a free key</b></a> ·
  <a href="https://flightbyte.dev/docs/reference"><b>API reference</b></a> ·
  <a href="https://flightbyte.dev/docs/webhooks"><b>Webhook docs</b></a> ·
  <a href="https://t.me/flightbyte"><b>Support</b></a>
</p>

---

## Quick start

1. Get a free API key at [app.flightbyte.dev/signup](https://app.flightbyte.dev/signup?utm_source=pub.dev&utm_medium=readme&utm_campaign=dart-sdk).
2. Add the package:

   | | Command |
   | --- | --- |
   | **Dart** | `dart pub add flightbyte` |
   | **Flutter** | `flutter pub add flightbyte` |

3. Look a flight up:

   ```dart
   import 'package:flightbyte/flightbyte.dart';

   final client = FlightByteClient(apiKey: 'frk_live_...');

   final flight = await client.flights.get(
     carrier: 'TK',
     flightNumber: '1848',
     date: '2026-09-08', // local departure date at the origin
   );

   print(flight.status.label);                    // Scheduled
   print(flight.departure.gate);                  // A11
   print(flight.departure.times.bestGate?.local); // 2026-09-08T12:25:00.000
   print(flight.departure.delayMinutes);          // 15

   client.close();
   ```

`FlightByteClient.formatDate(DateTime)` turns a date into the `YYYY-MM-DD` the API expects. To try it from a terminal, run the bundled example:

```bash
export FLIGHTBYTE_API_KEY=frk_live_...
dart run example/main.dart TK 1 2026-11-10
```

```text
Turkish Airlines TK1 on 2026-11-10
  IST → JFK  Departed (en_route)
  departs 2026-11-10T15:17:00.000 from gate F7
  arrives 2026-11-10T18:14:00.000
  quota: 28 of 30 left this minute
```

## What you can do

| You want to | You call |
| --- | --- |
| *Show a passenger their gate and delay* | `client.flights.get(...)` returns the live snapshot: phase, gate, terminal, baggage belt, scheduled, estimated and actual times, delay, aircraft and codeshares. |
| *Look up TK1 tomorrow, which flies two legs* | Pass `origin: 'IST'`. Without it the snapshot lists every leg in `alternates`, and a subscription refuses to guess: the `BadRequestException` carries the `legs` to choose from. |
| *Be told when anything changes* | `client.subscriptions.create(...)` starts the watch and returns the signing secret, shown once. |
| *Find out why webhooks stopped arriving* | `client.subscriptions.get(id)` and `deliveries(id)` show the status and the HTTP code and error of every recent attempt. |
| *Trust a webhook on your server* | `Webhook.constructEvent(...)` checks the signature against the raw body and decodes the event. |

## API

**Flights**: read-only.

| Method | What it does |
| --- | --- |
| `flights.get` | Live status of one flight leg, and every leg the number flies that day.<br><sub>`GET /v1/flights/{carrier}/{flightNumber}/{date}`</sub> |
| `flights.timeline` | The airline's own change history for a leg, newest first.<br><sub>`GET /v1/flights/{carrier}/{flightNumber}/{date}/timeline`</sub> |

**Subscriptions**

| Method | What it does | Access |
| --- | --- | --- |
| `subscriptions.create` | Watch a flight and get a signed webhook for every change. Counts as a watched flight on your plan; pass `idempotencyKey` so a retry never counts twice.<br><sub>`POST /v1/subscriptions`</sub> | writes |
| `subscriptions.list` | One page of your subscriptions, filtered by status, carrier, number or date.<br><sub>`GET /v1/subscriptions`</sub> | read-only |
| `subscriptions.listAll` | Every matching subscription as a `Stream`, fetched page by page.<br><sub>`GET /v1/subscriptions`</sub> | read-only |
| `subscriptions.get` | One subscription with its status and delivery counters.<br><sub>`GET /v1/subscriptions/{id}`</sub> | read-only |
| `subscriptions.update` | Change the webhook URL, event filter, delay threshold, headers or metadata.<br><sub>`PATCH /v1/subscriptions/{id}`</sub> | writes |
| `subscriptions.pause` | Stop polling and deliveries without losing anything.<br><sub>`POST /v1/subscriptions/{id}/pause`</sub> | writes |
| `subscriptions.resume` | Resume a paused or auto-suspended subscription.<br><sub>`POST /v1/subscriptions/{id}/resume`</sub> | writes |
| `subscriptions.delete` | Delete a subscription for good.<br><sub>`DELETE /v1/subscriptions/{id}`</sub> | **destructive** |
| `subscriptions.sendTest` | Send a signed `subscription.test` webhook to the subscription's URL.<br><sub>`POST /v1/subscriptions/{id}/test`</sub> | writes |
| `subscriptions.deliveries` | Recent delivery attempts with HTTP status and errors.<br><sub>`GET /v1/subscriptions/{id}/deliveries`</sub> | read-only |
| `subscriptions.events` | Recent events with the exact payloads that were sent.<br><sub>`GET /v1/subscriptions/{id}/events`</sub> | read-only |
| `subscriptions.secret` | Reveal the signing secret again.<br><sub>`GET /v1/subscriptions/{id}/secret`</sub> | read-only |
| `subscriptions.rotateSecret` | Generate a new signing secret. Previous signatures stop validating.<br><sub>`POST /v1/subscriptions/{id}/secret/rotate`</sub> | writes |

**Countries**: read-only.

| Method | What it does |
| --- | --- |
| `countries.list` | Every country with its name in any language, emoji and flag URLs.<br><sub>`GET /v1/countries`</sub> |
| `countries.get` | One country by its ISO 3166-1 alpha-2 code.<br><sub>`GET /v1/countries/{code}`</sub> |
| `countries.flagUrl` | The URL of a country's SVG flag, 4:3 or square. Needs no key, so it can go straight into an image widget.<br><sub>`GET /v1/flags/{code}.svg`</sub> |

Parameters carry the API's own names (`carrier`, `flightNumber`, `date`, `origin`, `webhookUrl`, `Idempotency-Key`, …), and the models carry every field of the API's JSON. The full snapshot is documented under [Flights](https://flightbyte.dev/docs/flights).

## Watch a flight

```dart
final created = await client.subscriptions.create(
  carrier: 'TK',
  flightNumber: '1848',
  date: '2026-09-08',
  webhookUrl: Uri.parse('https://api.example.com/hooks/flights'),
  events: [
    FlightChangeType.departureGateChanged,
    FlightChangeType.delayIncreased,
    FlightChangeType.departed,
  ],
  metadata: {'bookingId': 'BK-1042'},
  idempotencyKey: 'BK-1042', // safe to retry
);

// Shown in full only now: store it where your webhook receiver can read it.
final signingSecret = created.secret;
```

FlightByte only delivers to public HTTPS addresses. To receive on your machine, expose the port with a tunnel (`cloudflared tunnel --url http://localhost:8080` or `ngrok http 8080`) and use that URL. `subscriptions.sendTest(id)` sends a signed `subscription.test` whenever you want to see the path work.

## Receive webhooks

A receiver has to do four things, in this order: verify the signature against the raw body, deduplicate on the event id, answer `2xx` before doing the work, and branch on the event type. With [shelf](https://pub.dev/packages/shelf):

```dart
import 'dart:async';

import 'package:flightbyte/flightbyte.dart';
import 'package:shelf/shelf.dart';

Future<Response> flightHook(Request request) async {
  final payload = await request.readAsString(); // raw body, before any parsing
  final WebhookEvent event;
  try {
    event = Webhook.constructEvent(
      payload: payload,
      signature: request.headers[Webhook.signatureHeader],
      secret: signingSecret,
    );
  } on WebhookSignatureException {
    return Response(401, body: 'bad signature');
  }

  // A retry carries the same id: answer it, but don't handle it twice.
  if (!await markHandled(event.id)) return Response(204);

  // Answer first: FlightByte treats a delivery as failed after 10 seconds.
  unawaited(handle(event));
  return Response(204);
}

Future<void> handle(WebhookEvent event) async {
  switch (event.type) {
    case WebhookEventType.flightUpdated:
      for (final change in event.changes) {
        print('${event.flightKey} ${change.type.value}: ${change.message}');
      }
    case WebhookEventType.subscriptionCompleted:
      print('${event.flightKey} finished');
    default:
      break;
  }
}
```

<details>
<summary><b>How the signature works</b></summary>

<br>

```text
x-flightbyte-signature: t=1789305971,v1=5f1c9a...e3b2
v1 = HMAC-SHA256(secret, "<t>." + <raw body>)
```

`Webhook.verify` computes the HMAC over the body you received, not over JSON you parsed and serialised again, compares it in constant time, accepts any of several `v1` values, and rejects a `t` more than five minutes from now. An empty secret throws an `ArgumentError` instead of being used as a key, since anyone can sign with an empty key. `Webhook.sign` produces the same header, for testing your receiver. The test suite checks both against signatures made by the API's own signer.

The reasons behind each step are in [Verifying webhook signatures](https://flightbyte.dev/guides/verifying-webhook-signatures), and reference receivers in Node.js, Python and Go are in [flightbyte-webhook-examples](https://github.com/FlightByte-dev/flightbyte-webhook-examples).

</details>

## Errors

Every failed request throws a subclass of the sealed `FlightByteException`, so a `switch` over it is checked for completeness.

| Exception | Status | When, and what to do |
| --- | --- | --- |
| `BadRequestException` | `400` | Invalid input; `messages` has one line per field. For a number that flies twice, `legs` lists them: pass one's `origin`. |
| `AuthenticationException` | `401` | Missing, invalid, revoked or expired API key. |
| `PaymentRequiredException` | `402` | No watched flights left this period. `code` says why (`watched_flight_limit` or `overage_cap_reached`); `resetsAt` says when the count resets. |
| `PermissionDeniedException` | `403` | The account is suspended, or an OAuth token lacks the scope (`code`). |
| `NotFoundException` | `404` | The flight did not operate that day, or no such subscription. |
| `RateLimitException` | `429` | A minute, day or month quota is used up. Wait `retryAfter`. |
| `UpstreamException` | `502` | The flight data provider failed. Retry shortly. |
| `ServerException`, `UnexpectedStatusException` | other | Anything else. `requestId` is what support asks for. |
| `FlightByteConnectionException` | none | No response at all: network error, TLS failure or timeout. `cause` holds the underlying error. |

```dart
try {
  await client.subscriptions.create(/* ... */);
} on BadRequestException catch (e) {
  if (e.legs.isEmpty) rethrow;
  print('Pick a leg: ${e.legs.map((l) => l.origin).join(', ')}');
} on PaymentRequiredException catch (e) {
  print('No watched flights left until ${e.resetsAt}');
} on RateLimitException catch (e) {
  await Future<void>.delayed(e.retryAfter ?? const Duration(seconds: 5));
}
```

Every status is explained in the [errors docs](https://flightbyte.dev/docs/errors).

## Built for Flutter and Dart servers

- **Dart servers, CLIs and the backend behind your Flutter app.** It runs everywhere Dart does: iOS, Android, web, macOS, Windows and Linux.
- **Two dependencies.** [`http`](https://pub.dev/packages/http) and [`crypto`](https://pub.dev/packages/crypto), both from the Dart team.
- **Your key stays on your server.** An API key or a signing secret shipped inside a mobile or web app can be pulled out of it by anyone who has the app. In Flutter, call your own backend and let the backend use this package. Flag images are the exception: `countries.flagUrl` needs no key.
- **Your key stays with the API.** The client follows a redirect only for a read, and only on the API's own origin, so a misdirected answer cannot carry the key elsewhere and a write is never sent twice.
- **New API values don't break old apps.** A phase, status, change type or event type added after this release decodes to an `unknown` member instead of throwing, and the raw string is kept (`typeValue`, `statusValue`, `phaseValue`).
- **Zero stays apart from unknown.** Values the API may leave out are nullable, so a delay of `0` and no delay reading are different things.
- **Errors say what to do next.** A number that flies twice comes back with its legs, a `429` with how long to wait, a `402` with the reason and when the allowance resets.
- **Quotas are visible.** `client.lastRateLimit` holds the minute, day and month windows from the latest response's `X-RateLimit-*` headers.

## Configuration

```dart
final client = FlightByteClient(
  apiKey: 'frk_live_...',
  baseUrl: Uri.parse('http://localhost:3000/v1'),
  httpClient: myClient,
  timeout: const Duration(seconds: 10),
);
```

| Parameter | Default | Meaning |
| --- | --- | --- |
| `apiKey` | required | Your API key, sent as `x-api-key`. |
| `baseUrl` | `https://api.flightbyte.dev/v1` | API base URL, e.g. `http://localhost:3000/v1` for a local API. |
| `httpClient` | a new `http.Client` | Bring your own for retries, logging or tests. A client you pass is not closed by `close()`. |
| `timeout` | 30 seconds | Bounds each request, response body included. When it runs out, the request is aborted, not left running. |

## Development

```bash
dart pub get
dart test                          # everything, against a mocked HTTP client
dart analyze --fatal-infos
dart format --set-exit-if-changed .
dart pub publish --dry-run
```

The tests never touch the real API and need no key. They cover every method's request mapping, the error mapping for each status, the models against fixtures shaped like the API's JSON, and webhook verification against signatures made with Node's `createHmac` exactly as the API signs them. CI runs the same commands on every push.

How to add a field, an enum value or an endpoint is in [CONTRIBUTING.md](CONTRIBUTING.md). Report security issues by email, as [SECURITY.md](SECURITY.md) explains, never in a public issue.

<details>
<summary><b>Project layout</b></summary>

```text
lib/
  flightbyte.dart          public exports
  src/client.dart          FlightByteClient
  src/transport.dart       requests, headers, timeouts, error mapping
  src/resources/           flights, subscriptions, countries
  src/models/              snapshots, subscriptions, deliveries, events, enums
  src/errors.dart          the sealed FlightByteException hierarchy
  src/webhook.dart         Webhook.verify, constructEvent and sign
  src/rate_limit.dart      X-RateLimit-* headers
example/main.dart          looks a flight up from the terminal
test/fixtures/             API-shaped JSON and signed webhook vectors
tool/webhook_vectors.mjs   regenerates the signed vectors with Node, as the API signs
tool/release_notes.sh      a version's CHANGELOG.md section, for the GitHub release
```

</details>

<details>
<summary><b>Releasing</b></summary>

1. Bump `version` in `pubspec.yaml` and `packageVersion` in `lib/src/version.dart`; a test fails if they differ.
2. Give the version its own `## <version>` section in `CHANGELOG.md`.
3. Push a tag such as `v1.0.1`.

The publish workflow checks that the tag, `pubspec.yaml` and `lib/src/version.dart` agree and that the changelog has the section, publishes to pub.dev unless that version is already there, and creates the GitHub release from the changelog section. Run it by hand from the Actions tab to rehearse without publishing. Publishing from a tag needs automated publishing enabled for this repository on the package's pub.dev admin page; the first release is published by hand with `dart pub publish`.

</details>

## License

[MIT](LICENSE)

<br>

<p align="center">
  <a href="https://flightbyte.dev"><img src="assets/icon.svg" alt="FlightByte" width="36"></a>
  <br>
  <sub><b>FlightByte</b> · Flight intelligence, byte by byte · <a href="https://flightbyte.dev">flightbyte.dev</a></sub>
</p>
