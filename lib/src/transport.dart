import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'errors.dart';
import 'rate_limit.dart';
import 'version.dart';

const _isWeb = bool.fromEnvironment('dart.library.js_interop');

/// Sends authenticated requests and turns error statuses into exceptions.
///
/// Internal: reach the API through `FlightByteClient`.
final class Transport {
  /// Creates a [Transport].
  Transport({
    required this.apiKey,
    required this.baseUrl,
    required this.httpClient,
    required this.timeout,
    required this.ownsClient,
  });

  /// The API key sent as `X-API-Key`.
  final String apiKey;

  /// The API root, for example `https://api.flightbyte.dev/v1`.
  final Uri baseUrl;

  /// The underlying HTTP client.
  final http.Client httpClient;

  /// Applies to the whole request, response body included.
  final Duration timeout;

  /// Whether [close] closes [httpClient].
  final bool ownsClient;

  /// The quota headers of the latest response that carried them.
  RateLimitInfo? lastRateLimit;

  /// Builds the URL for [path] under [baseUrl]. `null` query values are dropped.
  Uri url(List<String> path, [Map<String, Object?>? query]) {
    final params = <String, String>{
      for (final entry in (query ?? const <String, Object?>{}).entries)
        if (entry.value != null) entry.key: '${entry.value}',
    };
    return baseUrl.replace(
      pathSegments: [
        ...baseUrl.pathSegments.where((s) => s.isNotEmpty),
        ...path,
      ],
      queryParameters: params.isEmpty ? null : params,
    );
  }

  /// Sends a request and returns the decoded JSON body, or `null` when the
  /// response has none.
  Future<Object?> send(
    String method,
    List<String> path, {
    Map<String, Object?>? query,
    Object? body,
    Map<String, String>? headers,
  }) async {
    final target = url(path, query);
    final http.Response response;
    try {
      response =
          await _exchange(method, target, body, headers).timeout(timeout);
    } on TimeoutException catch (error) {
      throw FlightByteConnectionException(
        '$method $target timed out after ${timeout.inSeconds}s.',
        cause: error,
      );
    } on http.ClientException catch (error) {
      throw FlightByteConnectionException(
        '$method $target failed: ${error.message}',
        cause: error,
      );
    }

    final quota = RateLimitInfo.fromHeaders(response.headers);
    if (!quota.isEmpty) lastRateLimit = quota;

    final text = utf8.decode(response.bodyBytes, allowMalformed: true);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FlightByteApiException.fromResponse(
          response.statusCode, text, response.headers);
    }
    if (text.trim().isEmpty) return null;
    try {
      return jsonDecode(text);
    } on FormatException catch (error) {
      throw FormatException(
        'Expected JSON from $method $target, got: '
        '${text.length > 200 ? '${text.substring(0, 200)}...' : text}',
        error.source,
      );
    }
  }

  /// Sends the request and follows redirects that stay on the same origin.
  ///
  /// Redirects are followed here rather than by the HTTP client, because
  /// `dart:io` copies every header, `x-api-key` included, to whatever host a
  /// `Location` names. A redirect to another scheme, host or port is not
  /// followed: the 3xx response comes back and [send] throws it as an
  /// `UnexpectedStatusException`, so the key never leaves the API's origin.
  /// Browsers follow redirects themselves, so this applies to the VM only.
  Future<http.Response> _exchange(
    String method,
    Uri target,
    Object? body,
    Map<String, String>? headers,
  ) async {
    var current = target;
    for (var hops = 0;; hops++) {
      final request = http.Request(method, current)
        ..followRedirects = false
        ..headers.addAll({
          'x-api-key': apiKey,
          'accept': 'application/json',
          if (!_isWeb) 'user-agent': 'flightbyte-dart/$packageVersion',
          ...?headers,
        });
      if (body != null) {
        request
          ..headers['content-type'] = 'application/json; charset=utf-8'
          ..body = jsonEncode(body);
      }
      final response =
          await httpClient.send(request).then(http.Response.fromStream);

      final location = response.headers['location'];
      if (!_redirects.contains(response.statusCode) ||
          location == null ||
          !(method == 'GET' || method == 'HEAD') ||
          hops >= _maxRedirects) {
        return response;
      }
      final next = current.resolve(location);
      if (!_sameOrigin(current, next)) return response;
      current = next;
    }
  }

  static const _redirects = {301, 302, 303, 307, 308};
  static const _maxRedirects = 5;

  static bool _sameOrigin(Uri a, Uri b) =>
      a.scheme == b.scheme && a.host == b.host && a.port == b.port;

  /// Closes the HTTP client when this transport created it.
  void close() {
    if (ownsClient) httpClient.close();
  }
}
