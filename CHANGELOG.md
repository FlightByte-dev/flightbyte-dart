## 1.0.0

- First release.
- `FlightByteClient` with `flights` (`get`, `timeline`), `subscriptions` (`create`, `list`, `listAll`, `get`, `update`, `delete`, `pause`, `resume`, `sendTest`, `deliveries`, `events`, `secret`, `rotateSecret`) and `countries` (`list`, `get`, `flagUrl`).
- Typed models for flights, subscriptions, deliveries and webhook events, with `unknown` fallbacks for enum values added later.
- `FlightTimeline.count`, the entry count the API sends with a flight's timeline, falling back to `entries.length` when absent.
- A sealed `FlightByteException` hierarchy that maps every API error status. `PaymentRequiredException` reads all three 402 reasons, including `credits_exhausted` with `balance` and `expiresAt` when prepaid credits are used up.
- `Webhook.verify`, `Webhook.constructEvent` and `Webhook.sign` for `x-flightbyte-signature` webhook signatures. An empty signing secret throws an `ArgumentError`, since anyone can sign with an empty key.
- An empty path parameter (a subscription id, a carrier, a flight number, a date, a country code) throws an `ArgumentError` before anything is sent, instead of asking for another URL.
- Every failure to get a response is a `FlightByteConnectionException`, including what your own `http.Client` or `dart:io` throws directly, such as a TLS `HandshakeException`. A timeout aborts the request in flight.
- `client.lastRateLimit` from the `X-RateLimit-*` headers.
- `X-API-Key` never leaves the API's origin. Redirects are followed only on the same scheme, host and port, for GET and HEAD and at most five hops; any other redirect throws an `UnexpectedStatusException` with the 3xx status and `headers['location']`. Browsers follow redirects themselves, so this applies to the Dart VM and Flutter on mobile and desktop.
