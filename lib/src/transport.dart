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
    final request = http.Request(method, url(path, query))
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

    final http.Response response;
    try {
      response = await httpClient
          .send(request)
          .then(http.Response.fromStream)
          .timeout(timeout);
    } on TimeoutException catch (error) {
      throw FlightByteConnectionException(
        '$method ${request.url} timed out after ${timeout.inSeconds}s.',
        cause: error,
      );
    } on http.ClientException catch (error) {
      throw FlightByteConnectionException(
        '$method ${request.url} failed: ${error.message}',
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
        'Expected JSON from $method ${request.url}, got: '
        '${text.length > 200 ? '${text.substring(0, 200)}...' : text}',
        error.source,
      );
    }
  }

  /// Closes the HTTP client when this transport created it.
  void close() {
    if (ownsClient) httpClient.close();
  }
}
