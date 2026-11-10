/// One quota window as reported by the `X-RateLimit-*` response headers.
final class RateLimitWindow {
  /// Creates a [RateLimitWindow].
  const RateLimitWindow(
      {required this.limit, required this.remaining, this.resetAt});

  /// Requests the window allows.
  final int limit;

  /// Requests left in the window.
  final int remaining;

  /// When the window resets.
  final DateTime? resetAt;

  @override
  String toString() =>
      '$remaining/$limit${resetAt == null ? '' : ' until $resetAt'}';
}

/// The quota state sent with a response. Windows the key has no limit on are
/// `null`; unlimited keys get no headers at all, so every window is `null`.
final class RateLimitInfo {
  /// Creates a [RateLimitInfo].
  const RateLimitInfo({this.minute, this.day, this.month});

  /// Reads the `X-RateLimit-{Limit,Remaining,Reset}-{Minute,Day,Month}`
  /// headers. Header names must be lower-cased, as `package:http` gives them.
  factory RateLimitInfo.fromHeaders(Map<String, String> headers) =>
      RateLimitInfo(
        minute: _window(headers, 'minute'),
        day: _window(headers, 'day'),
        month: _window(headers, 'month'),
      );

  /// The per-minute window.
  final RateLimitWindow? minute;

  /// The per-day window.
  final RateLimitWindow? day;

  /// The per-month window.
  final RateLimitWindow? month;

  /// Whether no window was reported.
  bool get isEmpty => minute == null && day == null && month == null;

  @override
  String toString() =>
      'RateLimitInfo(minute: $minute, day: $day, month: $month)';
}

RateLimitWindow? _window(Map<String, String> headers, String name) {
  final limit = int.tryParse(headers['x-ratelimit-limit-$name'] ?? '');
  final remaining = int.tryParse(headers['x-ratelimit-remaining-$name'] ?? '');
  if (limit == null || remaining == null) return null;
  final reset = int.tryParse(headers['x-ratelimit-reset-$name'] ?? '');
  return RateLimitWindow(
    limit: limit,
    remaining: remaining,
    resetAt: reset == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(reset * 1000, isUtc: true),
  );
}
