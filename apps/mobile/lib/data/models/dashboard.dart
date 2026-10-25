import '../json_read.dart';
import 'hub_flight.dart';
import 'shipment.dart';

class HubNotice {
  const HubNotice({required this.tag, required this.text});

  final String tag;
  final String text;

  factory HubNotice.fromJson(Map<String, Object?> json) {
    return HubNotice(tag: requiredString(json, 'tag'), text: requiredString(json, 'text'));
  }
}

bool hubNoticeAllowed(HubNotice notice) {
  if (notice.tag != 'WEIGHT' && notice.tag != 'FLIGHT') return false;
  if (notice.text.contains('৳') || notice.text.contains('¥')) return false;
  return true;
}

class HubIncoming {
  const HubIncoming({required this.kg, required this.count, required this.flightCode, required this.flightDate});

  final double kg;
  final int count;
  final String? flightCode;
  final String? flightDate;

  factory HubIncoming.fromJson(Map<String, Object?> json) {
    return HubIncoming(
      kg: requiredDouble(json, 'kg'),
      count: requiredInt(json, 'count'),
      flightCode: requiredNullableString(json, 'flightCode'),
      flightDate: requiredNullableString(json, 'flightDate'),
    );
  }
}

class HubDashboard {
  const HubDashboard({
    required this.todayLabel,
    required this.atHubCount,
    required this.incoming,
    required this.openTodoCount,
    required this.notices,
    required this.toProcess,
    this.upcomingFlights = const [],
  });

  final String todayLabel;
  final int atHubCount;
  final HubIncoming incoming;
  final int openTodoCount;
  final List<HubNotice> notices;
  final List<OperationalShipment> toProcess;

  /// Next flights into Dhaka, soonest first. Older servers do not send it.
  final List<HubFlight> upcomingFlights;

  factory HubDashboard.fromJson(Map<String, Object?> json) {
    final notices = [for (final item in requiredMapList(json, 'notices')) HubNotice.fromJson(item)].where(hubNoticeAllowed).toList();
    return HubDashboard(
      todayLabel: requiredString(json, 'todayLabel'),
      atHubCount: requiredInt(json, 'atHubCount'),
      incoming: HubIncoming.fromJson(asJsonMap(json['incoming'], 'incoming')),
      openTodoCount: requiredInt(json, 'openTodoCount'),
      notices: notices,
      toProcess: [for (final item in requiredMapList(json, 'toProcess')) OperationalShipment.fromJson(item)],
      upcomingFlights: json.containsKey('upcomingFlights')
          ? [for (final item in requiredMapList(json, 'upcomingFlights')) HubFlight.fromJson(item)]
          : const [],
    );
  }
}

class DashboardCounts {
  const DashboardCounts({required this.reviewCount, required this.openTodoCount});

  final int reviewCount;
  final int openTodoCount;

  factory DashboardCounts.fromJson(Map<String, Object?> json) {
    return DashboardCounts(
      reviewCount: requiredInt(json, 'reviewCount'),
      openTodoCount: requiredInt(json, 'openTodoCount'),
    );
  }
}
