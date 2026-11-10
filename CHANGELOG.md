## Unreleased

- `FlightTimeline.count`: the entry count the API sends with a flight's timeline, falling back to `entries.length` when absent. `FlightTimeline`'s constructor now takes `count`.
- Security: the client no longer sends `X-API-Key` to another host. `dart:io` followed redirects itself and copied every header to wherever `Location` pointed, so a redirect to another scheme, host or port leaked the key. Redirects are now followed only on the API's own origin, for GET and HEAD and at most five hops; any other redirect throws an `UnexpectedStatusException` with the 3xx status and `headers['location']`. Browsers follow redirects themselves, so this applies to the Dart VM and Flutter on mobile and desktop.

## 0.1.0

- First release.
- `FlightByteClient` with `flights` (`get`, `timeline`), `subscriptions` (`create`, `list`, `listAll`, `get`, `update`, `delete`, `pause`, `resume`, `sendTest`, `deliveries`, `events`, `secret`, `rotateSecret`) and `countries` (`list`, `get`, `flagUrl`).
- Typed models for flights, subscriptions, deliveries and webhook events, with `unknown` fallbacks for enum values added later.
- A sealed `FlightByteException` hierarchy that maps every API error status.
- `Webhook.verify`, `Webhook.constructEvent` and `Webhook.sign` for `x-flightbyte-signature` webhook signatures.
- `client.lastRateLimit` from the `X-RateLimit-*` headers.
