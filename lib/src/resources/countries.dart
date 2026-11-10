import '../json.dart';
import '../models/country.dart';
import '../transport.dart';

/// Country names, emoji and flags. Reach it as `client.countries`.
final class CountriesResource {
  /// Internal; use `FlightByteClient.countries`.
  CountriesResource(this._transport);

  final Transport _transport;

  /// Every country, sorted by name, with names in [lang] (for example `tr`).
  Future<List<Country>> list({String? lang}) async {
    final body =
        await _transport.send('GET', ['countries'], query: {'lang': lang});
    return readList(asJson(body, 'the country list'), 'data', Country.fromJson);
  }

  /// One country by its ISO 3166-1 alpha-2 [code].
  Future<Country> get(String code, {String? lang}) async {
    final body = await _transport
        .send('GET', ['countries', code], query: {'lang': lang});
    return Country.fromJson(asJson(body, 'the country'));
  }

  /// The URL of a country's SVG flag: 4:3, or 1:1 with [square]. Flags need no
  /// API key, so the URL can go straight into an image widget.
  Uri flagUrl(String code, {bool square = false}) => _transport.url(
        ['flags', '${code.toLowerCase()}.svg'],
        {if (square) 'shape': '1x1'},
      );
}
