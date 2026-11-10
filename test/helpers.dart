import 'dart:convert';
import 'dart:io';

import 'package:flightbyte/flightbyte.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Reads a file from `test/fixtures`.
String fixture(String name) => File('test/fixtures/$name').readAsStringSync();

/// Decodes a JSON fixture.
Map<String, Object?> jsonFixture(String name) =>
    (jsonDecode(fixture(name)) as Map).cast<String, Object?>();

/// A canned response.
final class Reply {
  Reply(this.status, [Object? body, this.headers = const {}])
      : body = body == null
            ? ''
            : body is String
                ? body
                : jsonEncode(body);

  final int status;
  final String body;
  final Map<String, String> headers;
}

/// A [FlightByteClient] over a [MockClient] that records every request and
/// answers with [replies] in order (the last one repeats).
final class Harness {
  Harness(List<Reply> replies, {Uri? baseUrl}) {
    var index = 0;
    final mock = MockClient((request) async {
      requests.add(request);
      final reply =
          replies[index < replies.length ? index++ : replies.length - 1];
      return http.Response.bytes(
        utf8.encode(reply.body),
        reply.status,
        headers: {
          'content-type': 'application/json; charset=utf-8',
          ...reply.headers
        },
        request: request,
      );
    });
    client = FlightByteClient(
        apiKey: 'frk_test_key', httpClient: mock, baseUrl: baseUrl);
  }

  late final FlightByteClient client;
  final List<http.Request> requests = [];

  http.Request get last => requests.last;

  Map<String, Object?> get lastJson =>
      (jsonDecode(last.body) as Map).cast<String, Object?>();
}
