// Looks a flight up and prints its status.
//
//   export FLIGHTBYTE_API_KEY=frk_live_...
//   dart run example/main.dart TK 1848 2026-09-08
//
// Set FLIGHTBYTE_BASE_URL to try a local API, for example
// http://localhost:3000/v1.
import 'dart:io';

import 'package:flightbyte/flightbyte.dart';

Future<void> main(List<String> args) async {
  final apiKey = Platform.environment['FLIGHTBYTE_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    stderr.writeln('Set FLIGHTBYTE_API_KEY first.');
    exitCode = 64;
    return;
  }
  final baseUrl = Platform.environment['FLIGHTBYTE_BASE_URL'];

  final carrier = args.isNotEmpty ? args[0] : 'TK';
  final flightNumber = args.length > 1 ? args[1] : '1';
  final date =
      args.length > 2 ? args[2] : FlightByteClient.formatDate(DateTime.now());

  final client = FlightByteClient(
    apiKey: apiKey,
    baseUrl: baseUrl == null ? null : Uri.parse(baseUrl),
  );
  try {
    final flight = await client.flights.get(
      carrier: carrier,
      flightNumber: flightNumber,
      date: date,
    );
    final dep = flight.departure;
    final arr = flight.arrival;
    print('${flight.carrier.name} $carrier$flightNumber on $date');
    print('  ${dep.airport.iata} → ${arr.airport.iata}  '
        '${flight.status.label} (${flight.status.phaseValue})');
    print('  departs ${dep.times.bestGate?.local ?? '?'}'
        '${dep.gate == null ? '' : ' from gate ${dep.gate}'}'
        '${(dep.delayMinutes ?? 0) > 0 ? ', ${dep.delayMinutes} min late' : ''}');
    print('  arrives ${arr.times.bestGate?.local ?? '?'}'
        '${arr.baggage == null ? '' : ', baggage ${arr.baggage}'}');

    final others = flight.alternates.where((leg) => !leg.selected);
    for (final leg in others) {
      print('  also operates ${leg.departureIata}-${leg.arrivalIata}; '
          'pass origin: "${leg.departureIata}" to pick it');
    }

    final quota = client.lastRateLimit?.minute;
    if (quota != null) {
      print('  quota: ${quota.remaining} of ${quota.limit} left this minute');
    }
  } on NotFoundException {
    print('$carrier$flightNumber did not operate on $date.');
  } on FlightByteException catch (e) {
    stderr.writeln(e);
    exitCode = 1;
  } finally {
    client.close();
  }
}
