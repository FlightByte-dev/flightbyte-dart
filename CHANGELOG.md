## 0.1.0

- First release.
- `FlightByteClient` with `flights` (`get`, `timeline`), `subscriptions` (`create`, `list`, `listAll`, `get`, `update`, `delete`, `pause`, `resume`, `sendTest`, `deliveries`, `events`, `secret`, `rotateSecret`) and `countries` (`list`, `get`, `flagUrl`).
- Typed models for flights, subscriptions, deliveries and webhook events, with `unknown` fallbacks for enum values added later.
- `FlightTimeline.count`, the entry count the API sends with a flight's timeline, falling back to `entries.length` when absent.
- A sealed `FlightByteException` hierarchy that maps every API error status.
- `Webhook.verify`, `Webhook.constructEvent` and `Webhook.sign` for `x-flightbyte-signature` webhook signatures.
- `client.lastRateLimit` from the `X-RateLimit-*` headers.
- `X-API-Key` never leaves the API's origin. Redirects are followed only on the same scheme, host and port, for GET and HEAD and at most five hops; any other redirect throws an `UnexpectedStatusException` with the 3xx status and `headers['location']`. Browsers follow redirects themselves, so this applies to the Dart VM and Flutter on mobile and desktop.
