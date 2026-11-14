import '../../l10n/l10n.dart';
import '../json_read.dart';
import 'hub_flight.dart';

/// Where a customer's orders are after the flight reached the Dhaka hub.
enum SortState {
  notReceived,
  toSort,
  sentBack,
  waitingAdmin,
  inDelivery,
  readyPickup,
  delivered,
  problem;

  static SortState parse(String value) => switch (value) {
        'to_sort' => SortState.toSort,
        'sent_back' => SortState.sentBack,
        'waiting_admin' => SortState.waitingAdmin,
        'in_delivery' => SortState.inDelivery,
        'ready_pickup' => SortState.readyPickup,
        'delivered' => SortState.delivered,
        'problem' => SortState.problem,
        _ => SortState.notReceived,
      };

  String get label => switch (this) {
        SortState.notReceived => tr('Not received'),
        SortState.toSort => tr('To sort'),
        SortState.sentBack => tr('Sent back'),
        SortState.waitingAdmin => tr('Waiting for admin'),
        SortState.inDelivery => tr('In delivery'),
        SortState.readyPickup => tr('Ready for pickup'),
        SortState.delivered => tr('Delivered'),
        SortState.problem => tr('Problem'),
      };

  /// The hub fills in the sort form in these states.
  bool get sortable => this == SortState.toSort || this == SortState.sentBack;

  /// Out with the courier or waiting at the hub for the customer.
  bool get outForDelivery =>
      this == SortState.inDelivery || this == SortState.readyPickup;
}

class SortOrder {
  const SortOrder({
    required this.code,
    required this.state,
    required this.statusLabel,
    required this.description,
    required this.categories,
    required this.bookedKg,
    required this.weighedKg,
    required this.weightDelta,
    required this.arrivedNote,
    required this.goodsPhotos,
    required this.devicePhotos,
    this.flyerName,
    this.exception,
    this.bill,
    this.bookedBill,
  });

  final String code;
  final SortState state;
  final String statusLabel;
  final String description;
  final List<String> categories;
  final double bookedKg;
  final double? weighedKg;

  /// Measured minus booked when over the warning threshold; null otherwise.
  final double? weightDelta;
  final String arrivedNote;
  final List<String> goodsPhotos;
  final List<DevicePhoto> devicePhotos;
  final String? flyerName;
  final String? exception;

  /// Admin only: the bill now, and what it was at the booked weight.
  final double? bill;
  final double? bookedBill;

  factory SortOrder.fromJson(Map<String, Object?> json) => SortOrder(
        code: requiredString(json, 'code'),
        state: SortState.parse(requiredString(json, 'state')),
        statusLabel: optionalString(json, 'statusLabel') ?? '',
        description: optionalString(json, 'description') ?? '',
        categories: json['categories'] is List
            ? asStringList(json['categories'], 'categories')
            : const [],
        bookedKg: requiredDouble(json, 'bookedKg'),
        weighedKg: optionalDouble(json, 'weighedKg'),
        weightDelta: optionalDouble(json, 'weightDelta'),
        arrivedNote: optionalString(json, 'arrivedNote') ?? '',
        goodsPhotos: json['goodsPhotos'] is List
            ? asStringList(json['goodsPhotos'], 'goodsPhotos')
            : const [],
        devicePhotos: DevicePhoto.listOf(json, 'devicePhotos'),
        flyerName: optionalString(json, 'flyerName'),
        exception: optionalString(json, 'exception'),
        bill: optionalDouble(json, 'bill'),
        bookedBill: optionalDouble(json, 'bookedBill'),
      );

  /// "Garments", or the booking description when there are no categories.
  String get what => categories.isNotEmpty
      ? categories.join(', ')
      : (description == '—' ? '' : description);
}

/// A packing photo and the order it was uploaded to.
class SortPhoto {
  const SortPhoto({required this.reference, required this.order});

  final String reference, order;

  factory SortPhoto.fromJson(Map<String, Object?> json) => SortPhoto(
      reference: requiredString(json, 'reference'),
      order: requiredString(json, 'order'));
}

class SortMoney {
  const SortMoney(
      {required this.bill,
      required this.paid,
      required this.due,
      required this.bookedBill});

  final double bill, paid, due, bookedBill;

  factory SortMoney.fromJson(Map<String, Object?> json) => SortMoney(
      bill: requiredDouble(json, 'bill'),
      paid: requiredDouble(json, 'paid'),
      due: requiredDouble(json, 'due'),
      bookedBill: requiredDouble(json, 'bookedBill'));
}

/// One customer's orders on one flight.
class SortGroup {
  const SortGroup({
    required this.customerCode,
    required this.state,
    required this.orders,
    required this.bookedKg,
    required this.measuredKg,
    required this.needsLook,
    required this.packages,
    required this.packingPhotos,
    required this.hubNote,
    required this.sentBackNote,
    this.customerName,
    this.customerPhone,
    this.customerAddress,
    this.partner,
    this.courierRef,
    this.sortedAt,
    this.sortedBy,
    this.approvedAt,
    this.approvedBy,
    this.sentBackAt,
    this.sentBackBy,
    this.money,
  });

  final String customerCode;

  /// Admin only; the hub sees the code.
  final String? customerName, customerPhone, customerAddress;
  final SortState state;
  final List<SortOrder> orders;
  final double bookedKg, measuredKg;
  final bool needsLook;
  final int packages;
  final List<SortPhoto> packingPhotos;
  final String hubNote;
  final String sentBackNote;
  final String? partner, courierRef;
  final DateTime? sortedAt, approvedAt, sentBackAt;
  final String? sortedBy, approvedBy, sentBackBy;
  final SortMoney? money;

  static DateTime? _time(Map<String, Object?> json, String key) {
    final raw = optionalString(json, key);
    return raw == null ? null : DateTime.tryParse(raw)?.toLocal();
  }

  factory SortGroup.fromJson(Map<String, Object?> json) => SortGroup(
        customerCode: requiredString(json, 'customerCode'),
        customerName: optionalString(json, 'customerName'),
        customerPhone: optionalString(json, 'customerPhone'),
        customerAddress: optionalString(json, 'customerAddress'),
        state: SortState.parse(requiredString(json, 'state')),
        orders: [
          for (final row in requiredMapList(json, 'orders'))
            SortOrder.fromJson(row)
        ],
        bookedKg: requiredDouble(json, 'bookedKg'),
        measuredKg: requiredDouble(json, 'measuredKg'),
        needsLook: json['needsLook'] == true,
        packages: optionalInt(json, 'packages') ?? 0,
        packingPhotos: json['packingPhotos'] is List
            ? [
                for (final row
                    in asMapList(json['packingPhotos'], 'packingPhotos'))
                  SortPhoto.fromJson(row)
              ]
            : const [],
        hubNote: optionalString(json, 'hubNote') ?? '',
        sentBackNote: optionalString(json, 'sentBackNote') ?? '',
        partner: optionalString(json, 'partner'),
        courierRef: optionalString(json, 'courierRef'),
        sortedAt: _time(json, 'sortedAt'),
        sortedBy: optionalString(json, 'sortedBy'),
        approvedAt: _time(json, 'approvedAt'),
        approvedBy: optionalString(json, 'approvedBy'),
        sentBackAt: _time(json, 'sentBackAt'),
        sentBackBy: optionalString(json, 'sentBackBy'),
        money: optionalMap(json, 'money') == null
            ? null
            : SortMoney.fromJson(optionalMap(json, 'money')!),
      );

  /// The admin sees the name; the hub sees the code.
  String get who => customerName ?? customerCode;

  /// Orders received at the hub (the ones counted and sorted).
  List<SortOrder> get received => [
        for (final o in orders)
          if (o.state != SortState.notReceived && o.state != SortState.problem)
            o
      ];

  bool get pickup => partner == 'Hub pickup';

  /// Which order each stored photo of this customer belongs to, for its
  /// download link.
  Map<String, String> get photoOrders => {
        for (final o in orders) ...{
          for (final r in o.goodsPhotos) r: o.code,
          for (final d in o.devicePhotos) d.reference: o.code,
        },
        for (final p in packingPhotos) p.reference: p.order,
      };
}

class SortFlight {
  const SortFlight(
      {required this.code,
      required this.number,
      required this.date,
      required this.arrTime,
      required this.status});

  final String code, number, date, arrTime, status;

  factory SortFlight.fromJson(Map<String, Object?> json) => SortFlight(
      code: requiredString(json, 'code'),
      number: optionalString(json, 'number') ?? requiredString(json, 'code'),
      date: optionalString(json, 'date') ?? '',
      arrTime: optionalString(json, 'arrTime') ?? '',
      status: optionalString(json, 'status') ?? '');
}

/// A flight's customers, as the hub sorts them or the admin checks them.
class SortBoard {
  const SortBoard(
      {required this.flight, required this.partners, required this.groups});

  final SortFlight flight;
  final List<String> partners;
  final List<SortGroup> groups;

  factory SortBoard.fromJson(Map<String, Object?> json) => SortBoard(
        flight: SortFlight.fromJson(asJsonMap(json['flight'], 'flight')),
        partners: json['partners'] is List
            ? asStringList(json['partners'], 'partners')
            : const [],
        groups: [
          for (final row in requiredMapList(json, 'groups'))
            SortGroup.fromJson(row)
        ],
      );

  SortGroup? group(String customer) =>
      groups.where((g) => g.customerCode == customer).firstOrNull;

  int count(SortState state) => groups.where((g) => g.state == state).length;
}

class ApprovalFlight {
  const ApprovalFlight({required this.flight, required this.groups});

  final SortFlight flight;
  final List<SortGroup> groups;

  factory ApprovalFlight.fromJson(Map<String, Object?> json) => ApprovalFlight(
        flight: SortFlight.fromJson(asJsonMap(json['flight'], 'flight')),
        groups: [
          for (final row in requiredMapList(json, 'groups'))
            SortGroup.fromJson(row)
        ],
      );
}

class Approvals {
  const Approvals({required this.flights, required this.count});

  final List<ApprovalFlight> flights;
  final int count;

  factory Approvals.fromJson(Map<String, Object?> json) => Approvals(
        flights: [
          for (final row in requiredMapList(json, 'flights'))
            ApprovalFlight.fromJson(row)
        ],
        count: optionalInt(json, 'count') ?? 0,
      );
}

class HubSortBucket {
  const HubSortBucket(
      {required this.flightCode,
      required this.number,
      required this.date,
      required this.customers,
      required this.orders});

  final String flightCode, number, date;
  final List<String> customers;
  final int orders;

  factory HubSortBucket.fromJson(Map<String, Object?> json) => HubSortBucket(
      flightCode: requiredString(json, 'flightCode'),
      number:
          optionalString(json, 'number') ?? requiredString(json, 'flightCode'),
      date: optionalString(json, 'date') ?? '',
      customers: json['customers'] is List
          ? asStringList(json['customers'], 'customers')
          : const [],
      orders: optionalInt(json, 'orders') ?? 0);
}

/// The hub's day: what to sort or fix, what waits for the admin, what is out.
class HubSortSummary {
  const HubSortSummary(
      {required this.toSort,
      required this.sentBack,
      required this.waitingAdmin,
      required this.inDelivery,
      this.waiting = const [],
      this.delivery = const []});

  final List<HubSortBucket> toSort, sentBack;

  /// Per flight: customers waiting for the admin, and out for delivery or
  /// pickup.
  final List<HubSortBucket> waiting, delivery;

  /// Customers waiting for the admin, and out for delivery or pickup.
  final int waitingAdmin, inDelivery;

  static const empty =
      HubSortSummary(toSort: [], sentBack: [], waitingAdmin: 0, inDelivery: 0);

  factory HubSortSummary.fromJson(Map<String, Object?> json) => HubSortSummary(
        toSort: [
          for (final row in requiredMapList(json, 'toSort'))
            HubSortBucket.fromJson(row)
        ],
        sentBack: [
          for (final row in requiredMapList(json, 'sentBack'))
            HubSortBucket.fromJson(row)
        ],
        waiting: _buckets(json, 'waiting'),
        delivery: _buckets(json, 'delivery'),
        waitingAdmin: optionalInt(json, 'waitingAdmin') ?? 0,
        inDelivery: optionalInt(json, 'inDelivery') ?? 0,
      );

  static List<HubSortBucket> _buckets(Map<String, Object?> json, String key) =>
      json[key] is List
          ? [
              for (final row in asMapList(json[key], key))
                HubSortBucket.fromJson(row)
            ]
          : const [];

  bool get isEmpty =>
      toSort.isEmpty &&
      sentBack.isEmpty &&
      waitingAdmin == 0 &&
      inDelivery == 0;
}

/// What the hub sends for one order when it sorts a customer.
class SortLine {
  const SortLine({required this.code, required this.kg, required this.arrived});

  final String code;
  final double kg;
  final String arrived;

  Map<String, Object?> toJson() => {'code': code, 'kg': kg, 'arrived': arrived};
}
