# Contributing

Thanks for helping. Bug reports, fixes and docs improvements are all welcome. For a change to the public API, open an issue first so we can agree on the shape before you write it.

## Set up

Using the package needs Dart 3.5 or later; developing it needs Dart 3.11 or later.

```bash
git clone https://github.com/FlightByte-dev/flightbyte-dart.git
cd flightbyte-dart
dart pub get
dart test
```

The tests never touch the real API and need no key.

## Before you open a pull request

```bash
dart format .
dart analyze --fatal-infos
dart test
dart pub publish --dry-run
```

CI runs the same four checks, and a pull request needs all of them green.

- **Every public member has a doc comment.** The analyzer enforces it (`public_member_api_docs`).
- **Every change has a test.** Requests are checked against a `MockClient` (see `test/helpers.dart`), never against the network.
- **Add a line to `CHANGELOG.md`** under a `## Unreleased` heading for anything a user would notice.

## How the code maps to the API

The package mirrors the [OpenAPI document](https://flightbyte.dev/openapi.json): parameter and field names are the API's own.

- **The API adds a field:** add it to the model in `lib/src/models/`, to its `fromJson` and `toJson`, and to the matching fixture in `test/fixtures/`. The round-trip test in `test/models_test.dart` fails if `toJson` drops it.
- **The API adds an enum value** (a phase, status, change type or event type): add a member to `lib/src/models/enums.dart`. Until then it decodes to `unknown`, which is why nothing breaks for users in the meantime.
- **The API adds an error code:** map it in `lib/src/errors.dart` and add a case to `test/errors_test.dart`.
- **The API adds an endpoint:** add a method to the resource in `lib/src/resources/`, a test in `test/resources_test.dart`, and a row to the README's API tables.

## Webhook signatures

`test/fixtures/webhook_vectors.json` holds signatures made with Node's `createHmac`, exactly as the API signs deliveries, so the Dart verifier is checked against the server and not only against itself. Do not edit those files by hand. To regenerate them, for example after adding a case to the script:

```bash
node tool/webhook_vectors.mjs
```

## Commit messages

One line that says what changed and why it matters, in plain words, for example `Subscriptions can be listed by origin airport`. Add a body when the reason is not obvious from the diff.

## Releasing

Maintainers only.

1. Bump `version` in `pubspec.yaml` and `packageVersion` in `lib/src/version.dart`; a test fails if they differ.
2. Rename `## Unreleased` in `CHANGELOG.md` to the new version.
3. Push a tag `v<version>`, for example `v1.0.1`.

The publish workflow checks that the tag, `pubspec.yaml` and `lib/src/version.dart` agree, publishes to pub.dev unless that version is already there, and creates the GitHub release from the version's `CHANGELOG.md` section. To rehearse a release without publishing anything, run the workflow by hand from the Actions tab.

## License

By contributing you agree that your contributions are licensed under the [MIT License](LICENSE).
