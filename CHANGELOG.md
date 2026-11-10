## 0.1.0

- First release.
- `FlightByteClient` with `flights` (`get`, `timeline`), `subscriptions` (`create`, `list`, `listAll`, `get`, `update`, `delete`, `pause`, `resume`, `sendTest`, `deliveries`, `events`, `secret`, `rotateSecret`) and `countries` (`list`, `get`, `flagUrl`).
- Typed models for flights, subscriptions, deliveries and webhook events, with `unknown` fallbacks for enum values added later.
- A sealed `FlightByteException` hierarchy that maps every API error status.
- `Webhook.verify`, `Webhook.constructEvent` and `Webhook.sign` for `x-flightbyte-signature` webhook signatures.
- `client.lastRateLimit` from the `X-RateLimit-*` headers.
