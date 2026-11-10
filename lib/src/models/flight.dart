import '../json.dart';
import 'country.dart';
import 'enums.dart';

/// An airport.
final class AirportRef {
  /// Creates an [AirportRef].
  const AirportRef({
    required this.iata,
    required this.name,
    required this.country,
    this.icao,
    this.code,
    this.city,
    this.state,
    this.timezone,
  });

  /// Decodes an [AirportRef] from JSON.
  factory AirportRef.fromJson(Json json) => AirportRef(
        iata: reqString(json, 'iata'),
        icao: optString(json, 'icao'),
        code: optString(json, 'code'),
        name: reqString(json, 'name'),
        city: optString(json, 'city'),
        state: optString(json, 'state'),
        country: reqObject(json, 'country', CountryRef.fromJson),
        timezone: optString(json, 'timezone'),
      );

  /// IATA code, for example `IST`.
  final String iata;

  /// ICAO code, for example `LTFM`.
  final String? icao;

  /// The upstream's own airport code; may differ from [iata].
  final String? code;

  /// Airport name.
  final String name;

  /// City.
  final String? city;

  /// State or region.
  final String? state;

  /// Country.
  final CountryRef country;

  /// IANA time zone, for example `Europe/Istanbul`.
  final String? timezone;

  /// Encodes this value as JSON.
  Json toJson() => {
        'iata': iata,
        'icao': icao,
        'code': code,
        'name': name,
        'city': city,
        'state': state,
        'country': country.toJson(),
        'timezone': timezone,
      };
}

/// A point in time, in UTC and in the airport's local time.
final class FlightTime {
  /// Creates a [FlightTime].
  const FlightTime({required this.utc, this.local, this.timezone});

  /// Decodes a [FlightTime] from JSON.
  factory FlightTime.fromJson(Json json) => FlightTime(
        utc: reqDate(json, 'utc'),
        local: optString(json, 'local'),
        timezone: optString(json, 'timezone'),
      );

  /// The instant, in UTC.
  final DateTime utc;

  /// Airport-local wall time without an offset, for example
  /// `2026-09-08T12:10:00.000`. Kept as a string because it carries no offset;
  /// pair it with [timezone] or the airport's time zone.
  final String? local;

  /// Time zone abbreviation, for example `EEST`.
  final String? timezone;

  /// Encodes this value as JSON.
  Json toJson() =>
      {'utc': isoOrNull(utc), 'local': local, 'timezone': timezone};
}

/// The gate and runway times of a departure or an arrival.
final class EndpointTimes {
  /// Creates an [EndpointTimes].
  const EndpointTimes({
    this.scheduledGate,
    this.estimatedGate,
    this.actualGate,
    this.scheduledRunway,
    this.estimatedRunway,
    this.actualRunway,
  });

  /// Decodes an [EndpointTimes] from JSON.
  factory EndpointTimes.fromJson(Json json) => EndpointTimes(
        scheduledGate: optObject(json, 'scheduledGate', FlightTime.fromJson),
        estimatedGate: optObject(json, 'estimatedGate', FlightTime.fromJson),
        actualGate: optObject(json, 'actualGate', FlightTime.fromJson),
        scheduledRunway:
            optObject(json, 'scheduledRunway', FlightTime.fromJson),
        estimatedRunway:
            optObject(json, 'estimatedRunway', FlightTime.fromJson),
        actualRunway: optObject(json, 'actualRunway', FlightTime.fromJson),
      );

  /// Scheduled gate time.
  final FlightTime? scheduledGate;

  /// Estimated gate time.
  final FlightTime? estimatedGate;

  /// Actual gate time.
  final FlightTime? actualGate;

  /// Scheduled runway time.
  final FlightTime? scheduledRunway;

  /// Estimated runway time.
  final FlightTime? estimatedRunway;

  /// Actual runway time.
  final FlightTime? actualRunway;

  /// The best known gate time: actual, else estimated, else scheduled.
  FlightTime? get bestGate => actualGate ?? estimatedGate ?? scheduledGate;

  /// Encodes this value as JSON.
  Json toJson() => {
        'scheduledGate': scheduledGate?.toJson(),
        'estimatedGate': estimatedGate?.toJson(),
        'actualGate': actualGate?.toJson(),
        'scheduledRunway': scheduledRunway?.toJson(),
        'estimatedRunway': estimatedRunway?.toJson(),
        'actualRunway': actualRunway?.toJson(),
      };
}

/// The departure or arrival side of a flight.
final class FlightEndpoint {
  /// Creates a [FlightEndpoint].
  const FlightEndpoint({
    required this.airport,
    required this.times,
    this.terminal,
    this.gate,
    this.baggage,
    this.bestTimeUtc,
    this.delayMinutes,
  });

  /// Decodes a [FlightEndpoint] from JSON.
  factory FlightEndpoint.fromJson(Json json) => FlightEndpoint(
        airport: reqObject(json, 'airport', AirportRef.fromJson),
        terminal: optString(json, 'terminal'),
        gate: optString(json, 'gate'),
        baggage: optString(json, 'baggage'),
        times: optObject(json, 'times', EndpointTimes.fromJson) ??
            const EndpointTimes(),
        bestTimeUtc: optDate(json, 'bestTimeUtc'),
        delayMinutes: optInt(json, 'delayMinutes'),
      );

  /// The airport.
  final AirportRef airport;

  /// Terminal.
  final String? terminal;

  /// Gate.
  final String? gate;

  /// Baggage carousel (arrival only).
  final String? baggage;

  /// Gate and runway times.
  final EndpointTimes times;

  /// Best known time in UTC: actual, else estimated, else scheduled.
  final DateTime? bestTimeUtc;

  /// Gate delay in minutes; negative when early.
  final int? delayMinutes;

  /// Encodes this value as JSON.
  Json toJson() => {
        'airport': airport.toJson(),
        'terminal': terminal,
        'gate': gate,
        'baggage': baggage,
        'times': times.toJson(),
        'bestTimeUtc': isoOrNull(bestTimeUtc),
        'delayMinutes': delayMinutes,
      };
}

/// The marketing carrier.
final class CarrierRef {
  /// Creates a [CarrierRef].
  const CarrierRef({required this.iata, required this.name, this.icao});

  /// Decodes a [CarrierRef] from JSON.
  factory CarrierRef.fromJson(Json json) => CarrierRef(
        iata: reqString(json, 'iata'),
        icao: optString(json, 'icao'),
        name: reqString(json, 'name'),
      );

  /// IATA code, for example `TK`.
  final String iata;

  /// ICAO code, for example `THY`.
  final String? icao;

  /// Airline name.
  final String name;

  /// Encodes this value as JSON.
  Json toJson() => {'iata': iata, 'icao': icao, 'name': name};
}

/// A codeshare flight number sold on the same flight.
final class CodeshareRef {
  /// Creates a [CodeshareRef].
  const CodeshareRef(
      {required this.carrier, required this.name, required this.flightNumber});

  /// Decodes a [CodeshareRef] from JSON.
  factory CodeshareRef.fromJson(Json json) => CodeshareRef(
        carrier: reqString(json, 'carrier'),
        name: reqString(json, 'name'),
        flightNumber: reqString(json, 'flightNumber'),
      );

  /// Carrier code.
  final String carrier;

  /// Carrier name.
  final String name;

  /// Flight number.
  final String flightNumber;

  /// Encodes this value as JSON.
  Json toJson() =>
      {'carrier': carrier, 'name': name, 'flightNumber': flightNumber};
}

/// The status of a flight.
final class FlightStatusInfo {
  /// Creates a [FlightStatusInfo].
  const FlightStatusInfo({
    required this.code,
    required this.label,
    required this.phaseValue,
    this.description,
    this.color,
    this.delayed = false,
    this.cancelled = false,
    this.diverted = false,
    this.departureGateDelayMinutes,
    this.arrivalGateDelayMinutes,
  });

  /// Decodes a [FlightStatusInfo] from JSON.
  factory FlightStatusInfo.fromJson(Json json) => FlightStatusInfo(
        code: reqString(json, 'code'),
        label: reqString(json, 'label'),
        description: optString(json, 'description'),
        color: optString(json, 'color'),
        phaseValue: optString(json, 'phase') ?? FlightPhase.unknown.value,
        delayed: readBool(json, 'delayed'),
        cancelled: readBool(json, 'cancelled'),
        diverted: readBool(json, 'diverted'),
        departureGateDelayMinutes: optInt(json, 'departureGateDelayMinutes'),
        arrivalGateDelayMinutes: optInt(json, 'arrivalGateDelayMinutes'),
      );

  /// Upstream status code: `S`, `A`, `L`, `C`, `D`, `R`, `U` or `NO`.
  final String code;

  /// Human-readable status, for example `Arrived`.
  final String label;

  /// Longer description, for example `On time`.
  final String? description;

  /// Suggested color, for example `green`.
  final String? color;

  /// The phase as sent by the API.
  final String phaseValue;

  /// The lifecycle phase.
  FlightPhase get phase => FlightPhase.fromValue(phaseValue);

  /// Whether the flight is delayed.
  final bool delayed;

  /// Whether the flight is cancelled.
  final bool cancelled;

  /// Whether the flight is diverted.
  final bool diverted;

  /// Departure gate delay in minutes.
  final int? departureGateDelayMinutes;

  /// Arrival gate delay in minutes.
  final int? arrivalGateDelayMinutes;

  /// Encodes this value as JSON.
  Json toJson() => {
        'code': code,
        'label': label,
        'description': description,
        'color': color,
        'phase': phaseValue,
        'delayed': delayed,
        'cancelled': cancelled,
        'diverted': diverted,
        'departureGateDelayMinutes': departureGateDelayMinutes,
        'arrivalGateDelayMinutes': arrivalGateDelayMinutes,
      };
}

/// The aircraft.
final class EquipmentInfo {
  /// Creates an [EquipmentInfo].
  const EquipmentInfo({this.tailNumber, this.iata, this.name, this.source});

  /// Decodes an [EquipmentInfo] from JSON.
  factory EquipmentInfo.fromJson(Json json) => EquipmentInfo(
        tailNumber: optString(json, 'tailNumber'),
        iata: optString(json, 'iata'),
        name: optString(json, 'name'),
        source: optString(json, 'source'),
      );

  /// Registration, for example `TC-LTP`.
  final String? tailNumber;

  /// IATA aircraft type, for example `32Q`.
  final String? iata;

  /// Aircraft name, for example `Airbus A321neo`.
  final String? name;

  /// Where the data came from, for example `Actual`.
  final String? source;

  /// Encodes this value as JSON.
  Json toJson() =>
      {'tailNumber': tailNumber, 'iata': iata, 'name': name, 'source': source};
}

/// Block times in minutes.
final class DurationInfo {
  /// Creates a [DurationInfo].
  const DurationInfo(
      {this.scheduledMinutes, this.estimatedMinutes, this.actualMinutes});

  /// Decodes a [DurationInfo] from JSON.
  factory DurationInfo.fromJson(Json json) => DurationInfo(
        scheduledMinutes: optInt(json, 'scheduledMinutes'),
        estimatedMinutes: optInt(json, 'estimatedMinutes'),
        actualMinutes: optInt(json, 'actualMinutes'),
      );

  /// Scheduled duration.
  final int? scheduledMinutes;

  /// Estimated duration.
  final int? estimatedMinutes;

  /// Actual duration.
  final int? actualMinutes;

  /// Encodes this value as JSON.
  Json toJson() => {
        'scheduledMinutes': scheduledMinutes,
        'estimatedMinutes': estimatedMinutes,
        'actualMinutes': actualMinutes,
      };
}

/// One entry of a flight's upstream history.
final class TimelineEntry {
  /// Creates a [TimelineEntry].
  const TimelineEntry({
    required this.occurredAt,
    required this.title,
    this.source,
    this.events = const [],
  });

  /// Decodes a [TimelineEntry] from JSON.
  factory TimelineEntry.fromJson(Json json) => TimelineEntry(
        occurredAt: reqDate(json, 'occurredAt'),
        title: reqString(json, 'title'),
        source: optString(json, 'source'),
        events: readStringList(json, 'events'),
      );

  /// When it happened.
  final DateTime occurredAt;

  /// Title, for example `Time Adjustment`.
  final String title;

  /// Source, for example `Airline`.
  final String? source;

  /// What changed, as sentences.
  final List<String> events;

  /// Encodes this value as JSON.
  Json toJson() => {
        'occurredAt': isoOrNull(occurredAt),
        'title': title,
        'source': source,
        'events': events,
      };
}

/// Another leg listed for the same flight number on the same date.
///
/// Flight numbers are not unique per day, so the API lists every leg and marks
/// the one the snapshot describes with [selected].
final class FlightLegRef {
  /// Creates a [FlightLegRef].
  const FlightLegRef({
    required this.departureIata,
    required this.arrivalIata,
    required this.selected,
    this.providerFlightId,
    this.carrier,
    this.scheduledDepartureLocal,
    this.scheduledArrivalLocal,
  });

  /// Decodes a [FlightLegRef] from JSON.
  factory FlightLegRef.fromJson(Json json) => FlightLegRef(
        providerFlightId: optString(json, 'providerFlightId'),
        carrier: optString(json, 'carrier'),
        departureIata: reqString(json, 'departureIata'),
        arrivalIata: reqString(json, 'arrivalIata'),
        scheduledDepartureLocal: optString(json, 'scheduledDepartureLocal'),
        scheduledArrivalLocal: optString(json, 'scheduledArrivalLocal'),
        selected: readBool(json, 'selected'),
      );

  /// Upstream flight id; pass it as `flightId` to select this leg.
  final String? providerFlightId;

  /// Operating carrier code.
  final String? carrier;

  /// Origin IATA code.
  final String departureIata;

  /// Destination IATA code.
  final String arrivalIata;

  /// Scheduled local departure, `HH:mm`.
  final String? scheduledDepartureLocal;

  /// Scheduled local arrival, `HH:mm`.
  final String? scheduledArrivalLocal;

  /// Whether this is the leg the snapshot describes.
  final bool selected;

  /// Encodes this value as JSON.
  Json toJson() => {
        'providerFlightId': providerFlightId,
        'carrier': carrier,
        'departureIata': departureIata,
        'arrivalIata': arrivalIata,
        'scheduledDepartureLocal': scheduledDepartureLocal,
        'scheduledArrivalLocal': scheduledArrivalLocal,
        'selected': selected,
      };
}

/// Everything known about one flight leg at one moment.
final class FlightSnapshot {
  /// Creates a [FlightSnapshot].
  const FlightSnapshot({
    required this.flightKey,
    required this.carrierCode,
    required this.flightNumber,
    required this.date,
    required this.fetchedAt,
    required this.carrier,
    required this.departure,
    required this.arrival,
    required this.status,
    this.providerFlightId,
    this.operatedBy,
    this.codeshares = const [],
    this.diverted,
    this.equipment = const EquipmentInfo(),
    this.duration = const DurationInfo(),
    this.timeline = const [],
    this.alternates = const [],
    this.fingerprint = '',
    this.cached = false,
  });

  /// Decodes a [FlightSnapshot] from JSON.
  factory FlightSnapshot.fromJson(Json json) => FlightSnapshot(
        flightKey: reqString(json, 'flightKey'),
        carrierCode: reqString(json, 'carrierCode'),
        flightNumber: reqString(json, 'flightNumber'),
        date: reqString(json, 'date'),
        providerFlightId: optString(json, 'providerFlightId'),
        fetchedAt: reqDate(json, 'fetchedAt'),
        carrier: reqObject(json, 'carrier', CarrierRef.fromJson),
        operatedBy: optString(json, 'operatedBy'),
        codeshares: readList(json, 'codeshares', CodeshareRef.fromJson),
        departure: reqObject(json, 'departure', FlightEndpoint.fromJson),
        arrival: reqObject(json, 'arrival', FlightEndpoint.fromJson),
        diverted: optObject(json, 'diverted', FlightEndpoint.fromJson),
        status: reqObject(json, 'status', FlightStatusInfo.fromJson),
        equipment: optObject(json, 'equipment', EquipmentInfo.fromJson) ??
            const EquipmentInfo(),
        duration: optObject(json, 'duration', DurationInfo.fromJson) ??
            const DurationInfo(),
        timeline: readList(json, 'timeline', TimelineEntry.fromJson),
        alternates: readList(json, 'alternates', FlightLegRef.fromJson),
        fingerprint: optString(json, 'fingerprint') ?? '',
        cached: readBool(json, 'cached'),
      );

  /// Stable key, for example `TK1848:2026-09-08` or `TK1:2026-09-08@IST-JFK`.
  final String flightKey;

  /// Carrier code from the request, for example `TK`.
  final String carrierCode;

  /// Flight number without leading zeros, for example `1848`.
  final String flightNumber;

  /// Local departure date at the origin, `YYYY-MM-DD`.
  final String date;

  /// Upstream flight id.
  final String? providerFlightId;

  /// When the API fetched this data from upstream.
  final DateTime fetchedAt;

  /// Marketing carrier.
  final CarrierRef carrier;

  /// Operating carrier name, when different.
  final String? operatedBy;

  /// Codeshare flight numbers.
  final List<CodeshareRef> codeshares;

  /// Departure side.
  final FlightEndpoint departure;

  /// Arrival side.
  final FlightEndpoint arrival;

  /// Where the flight actually went, when diverted.
  final FlightEndpoint? diverted;

  /// Status.
  final FlightStatusInfo status;

  /// Aircraft.
  final EquipmentInfo equipment;

  /// Block times.
  final DurationInfo duration;

  /// Upstream history, newest first.
  final List<TimelineEntry> timeline;

  /// Every leg listed for this flight number on this date.
  final List<FlightLegRef> alternates;

  /// Hash over the change-relevant fields.
  final String fingerprint;

  /// Whether a lookup was answered from the API's cache. Always `false` on
  /// snapshots inside webhook events.
  final bool cached;

  /// Encodes this value as JSON.
  Json toJson() => {
        'flightKey': flightKey,
        'carrierCode': carrierCode,
        'flightNumber': flightNumber,
        'date': date,
        'providerFlightId': providerFlightId,
        'fetchedAt': isoOrNull(fetchedAt),
        'carrier': carrier.toJson(),
        'operatedBy': operatedBy,
        'codeshares': [for (final c in codeshares) c.toJson()],
        'departure': departure.toJson(),
        'arrival': arrival.toJson(),
        'diverted': diverted?.toJson(),
        'status': status.toJson(),
        'equipment': equipment.toJson(),
        'duration': duration.toJson(),
        'timeline': [for (final t in timeline) t.toJson()],
        'alternates': [for (final a in alternates) a.toJson()],
        'fingerprint': fingerprint,
        'cached': cached,
      };
}

/// The response of `flights.timeline`.
final class FlightTimeline {
  /// Creates a [FlightTimeline].
  const FlightTimeline({required this.flightKey, required this.entries});

  /// Decodes a [FlightTimeline] from JSON.
  factory FlightTimeline.fromJson(Json json) => FlightTimeline(
        flightKey: reqString(json, 'flightKey'),
        entries: readList(json, 'data', TimelineEntry.fromJson),
      );

  /// The flight's key.
  final String flightKey;

  /// History entries, newest first.
  final List<TimelineEntry> entries;
}
