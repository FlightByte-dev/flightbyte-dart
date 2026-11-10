import '../json.dart';

/// A country as it appears inside an airport.
final class CountryRef {
  /// Creates a [CountryRef].
  const CountryRef({
    required this.code,
    required this.name,
    required this.emoji,
    required this.flagSvg,
    required this.flagSvgSquare,
  });

  /// Decodes a [CountryRef] from JSON.
  factory CountryRef.fromJson(Json json) => CountryRef(
        code: reqString(json, 'code'),
        name: reqString(json, 'name'),
        emoji: optString(json, 'emoji') ?? '',
        flagSvg: optString(json, 'flagSvg') ?? '',
        flagSvgSquare: optString(json, 'flagSvgSquare') ?? '',
      );

  /// ISO 3166-1 alpha-2 code, for example `TR`.
  final String code;

  /// Country name.
  final String name;

  /// Flag emoji.
  final String emoji;

  /// Absolute URL of the 4:3 SVG flag.
  final String flagSvg;

  /// Absolute URL of the 1:1 SVG flag.
  final String flagSvgSquare;

  /// Encodes this value as JSON.
  Json toJson() => {
        'code': code,
        'name': name,
        'emoji': emoji,
        'flagSvg': flagSvg,
        'flagSvgSquare': flagSvgSquare,
      };
}

/// A country from the `/countries` endpoints.
final class Country extends CountryRef {
  /// Creates a [Country].
  const Country({
    required super.code,
    required super.name,
    required super.emoji,
    required super.flagSvg,
    required super.flagSvgSquare,
    required this.alpha2,
    required this.hasFlag,
  });

  /// Decodes a [Country] from JSON.
  factory Country.fromJson(Json json) {
    final ref = CountryRef.fromJson(json);
    return Country(
      code: ref.code,
      name: ref.name,
      emoji: ref.emoji,
      flagSvg: ref.flagSvg,
      flagSvgSquare: ref.flagSvgSquare,
      alpha2: optString(json, 'alpha2') ?? ref.code,
      hasFlag: readBool(json, 'hasFlag'),
    );
  }

  /// ISO 3166-1 alpha-2 code.
  final String alpha2;

  /// Whether a flag image exists for this country.
  final bool hasFlag;

  @override
  Json toJson() => {...super.toJson(), 'alpha2': alpha2, 'hasFlag': hasFlag};
}
