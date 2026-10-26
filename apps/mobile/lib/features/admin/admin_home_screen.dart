import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/data_changes.dart';
import '../../data/models/flight.dart';
import '../../data/models/hub_flight.dart';
import '../../data/models/session_user.dart';
import '../../data/models/workspace.dart';
import '../../data/repositories/dashboard_repository.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/finance_parts.dart' show monthOnly;
import '../../widgets/flight_parts.dart'
    show CapacityText, DateBlock, MeterBar, dayMonth, heroAlert, heroSoft;
import '../../widgets/flow_parts.dart' show FlowChip;
import '../../widgets/quick_parts.dart';
import '../../widgets/ui.dart';
import '../customers/customer_form_screen.dart';
import '../customers/statement_screen.dart';
import '../finance/finance_screen.dart';
import '../finance/get_paid_screen.dart';
import '../flights/flight_detail_screen.dart';
import '../flights/flight_form_screen.dart';
import '../flights/flights_screen.dart';
import '../flights/ticket_import_screen.dart';
import '../flyers/flyer_detail_screen.dart';
import '../flyers/flyer_form_screen.dart';
import '../flyers/flyers_screen.dart';
import '../intake/intake_screen.dart';
import '../shipments/shipments_screen.dart';
import '../tasks/tasks_screen.dart';
import 'admin_shipment_screen.dart';
import 'payment_review_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen(
      {super.key,
      required this.dashboard,
      this.onOpenShipments,
      this.onOpenFinance});

  final DashboardRepository dashboard;

  /// Switch the shell to its tab; without them the screen is pushed.
  final VoidCallback? onOpenShipments;
  final VoidCallback? onOpenFinance;

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  AdminOverview? _data;
  String? _error;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    dataChanges.addListener(_onDataChanged);
    _load();
  }

  @override
  void dispose() {
    dataChanges.removeListener(_onDataChanged);
    super.dispose();
  }

  /// Something was deleted, archived or restored on another screen.
  void _onDataChanged() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.dashboard.overview();
      if (!mounted) return;
      setState(() => _data = data);
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final today = FlightDay.parse(DateTime.now().toIso8601String());
    return WorkspaceScaffold(
        root: true,
        title: tr('Overview'),
        subtitle: today == null
            ? 'SBExpress'
            : '${today.weekdayName} · ${today.day} ${today.month}',
        onRefresh: _load,
        actions: [
          FilledButton.icon(
              key: const Key('home-add'),
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(48, 44),
                  padding: const EdgeInsets.fromLTRB(12, 0, 16, 0),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                      fontFamily: 'HindSiliguri',
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
              onPressed: _add,
              icon: const Icon(Icons.add_rounded, size: 19),
              label: Text(tr('Add'))),
        ],
        children: [
          if (_loading && data == null) const LinearProgressIndicator(),
          if (_error != null) ErrorNote(message: _error!, onRetry: _load),
          if (data != null) ..._overview(data),
        ]);
  }

  List<Widget> _overview(AdminOverview data) {
    final attention = _attention(data);
    return [
      TileRow(children: [
        WorkTile(
            key: const Key('home-review'),
            icon: Icons.receipt_long_outlined,
            value: '${data.reviewCount}',
            label: tr('Receipts to review'),
            hot: data.reviewCount > 0,
            onTap: () => _push(const PaymentReviewScreen())),
        WorkTile(
            key: const Key('home-tasks'),
            icon: Icons.checklist_rounded,
            value: '${data.openTodoCount}',
            label: tr('Open tasks'),
            onTap: () => _push(TasksScreen(
                role: UserRole.admin, tasks: AppScope.of(context).tasks))),
        WorkTile(
            key: const Key('home-active'),
            icon: Icons.inventory_2_outlined,
            tone: ChipTone.neutral,
            value: '${data.activeShipmentCount}',
            label: tr('Active shipments'),
            onTap: _openShipments),
      ]),
      const SizedBox(height: 16),
      _MoneyCard(data: data, onFinance: _openFinance),
      const SizedBox(height: 16),
      TileRow(children: [
        OweTile(
            key: const Key('home-owed'),
            label: tr('Customers owe us'),
            amount: wholeBdt(data.unpaid),
            color: data.unpaid > 0 ? AppColors.danger : AppColors.ink,
            caption:
                '${data.collect == null ? tr('Finance') : tr('Get paid')} ›',
            link: true,
            onTap: data.collect == null
                ? _openFinance
                : () => _push(const GetPaidScreen())),
        if (data.flyerReceivables != null)
          OweTile(
              label: tr('Flyers owe us'),
              amount: wholeBdt(data.flyerReceivables!),
              caption: tr('ticket parts'),
              onTap: () => _push(const FlightsScreen())),
        if (data.payables != null)
          OweTile(
              label: tr('We owe'),
              amount: wholeBdt(data.payables!),
              color: data.payables! > 0 ? AppColors.accentInk : AppColors.ink,
              caption: tr('tickets · costs'),
              onTap: _openFinance),
      ]),
      const SizedBox(height: 22),
      SectionTitle(
          title: tr('Needs attention'),
          action: attention.isEmpty
              ? null
              : Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text('${attention.length}',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.muted)))),
      SurfaceGroup(children: [
        if (attention.isEmpty)
          AttentionRow(
              icon: Icons.check_rounded,
              tone: ChipTone.green,
              title: tr('Nothing needs attention right now'))
        else
          ...attention,
      ]),
      if (data.stageCounts != null) ...[
        const SizedBox(height: 16),
        _StageCard(counts: data.stageCounts!, onOpen: _openShipments),
      ],
      const SizedBox(height: 22),
      SectionTitle(
          title: tr('Flights'),
          action: TextButton(
              onPressed: () => _push(const FlightsScreen()),
              child: Text(tr('All flights')))),
      ..._flights(data),
    ];
  }

  /// Overdue bills, flights missing costs, the server's notices, this
  /// month's bills and flyers missing documents, most urgent first.
  List<Widget> _attention(AdminOverview data) {
    final collect = data.collect;
    final overdue = <Widget>[];
    final costs = <Widget>[];
    final weights = <Widget>[];
    final bills = <Widget>[];
    final documents = _missingDocs(data);
    final other = <Widget>[];
    if (collect != null && collect.overdueCount > 0) {
      overdue.add(AttentionRow(
          key: const Key('attention-overdue'),
          icon: Icons.schedule_rounded,
          tone: ChipTone.red,
          title: trn(collect.overdueCount, '{n} bill is overdue after delivery',
              '{n} bills are overdue after delivery'),
          detail: tr('{amount} to collect from handed-over shipments',
              {'amount': wholeBdt(collect.afterDeliveryDue)}),
          badge: StatusPill(label: tr('Overdue'), tone: ChipTone.red),
          onTap: () => _push(const GetPaidScreen())));
    }
    for (final flight in data.flights) {
      final missing = flight.missingCostCount ?? 0;
      if (missing <= 0) continue;
      costs.add(AttentionRow(
          icon: Icons.fact_check_outlined,
          title: trn(missing, '{n} shipment is missing costs',
              '{n} shipments are missing costs'),
          detail:
              '${displayFlightCode(flight.code)} · ${dayMonth(flight.date)}',
          onTap: () => _openFlight(flight.code)));
    }
    final upcoming = {
      for (final flight in data.flights)
        if (flight.status == 'upcoming') flight.code
    };
    var monthlyNotices = 0;
    for (final notice in data.notices) {
      switch (_readNotice(notice)) {
        case final _WeightNotice parsed:
          weights.add(AttentionRow(
              icon: Icons.scale_outlined,
              title: parsed.over
                  ? tr('{code} weighed {kg} kg more than booked',
                      {'code': parsed.code, 'kg': parsed.delta})
                  : tr('{code} weighed {kg} kg less than booked',
                      {'code': parsed.code, 'kg': parsed.delta}),
              detail: tr('{customer} · {weighed} kg vs {booked} kg', {
                'customer': parsed.customer,
                'weighed': parsed.weighed,
                'booked': parsed.booked
              }),
              onTap: () => _push(AdminShipmentScreen(code: parsed.code))));
        case final _FlightNotice parsed:
          // The flight cards below already show the next flight.
          if (upcoming.contains(parsed.code)) continue;
          other.add(AttentionRow(
              icon: Icons.flight_rounded,
              tone: ChipTone.blue,
              title: notice.text,
              onTap: () => _openFlight(parsed.code)));
        case final _BillNotice parsed:
          monthlyNotices++;
          bills.add(AttentionRow(
              icon: Icons.calendar_month_outlined,
              tone: ChipTone.blue,
              title: tr('Monthly bill: {name} owes {amount}',
                  {'name': parsed.name, 'amount': parsed.amount}),
              detail:
                  tr('Monthly · cycle closes {date}', {'date': parsed.closes}),
              onTap: () => _push(
                  StatementScreen(code: parsed.code, name: parsed.name))));
        case null:
          other.add(AttentionRow(
              icon: switch (notice.tag) {
                'WEIGHT' => Icons.scale_outlined,
                'FLIGHT' => Icons.flight_rounded,
                _ => Icons.event_note_outlined,
              },
              tone: noticeTone(notice.tag),
              title: notice.text));
      }
    }
    if (monthlyNotices == 0 && collect != null && collect.monthlyDue > 0) {
      bills.add(AttentionRow(
          icon: Icons.calendar_month_outlined,
          tone: ChipTone.blue,
          title: tr('{month} bills: {amount} still due', {
            'month': monthOnly(collect.month),
            'amount': wholeBdt(collect.monthlyDue)
          }),
          detail: trn(collect.monthlyCustomers, 'Due from {n} customer',
              'Due from {n} customers'),
          onTap: () => _push(const GetPaidScreen(initialTab: 1))));
    }
    return [...overdue, ...costs, ...weights, ...bills, ...documents, ...other];
  }

  /// Up to three flyers missing travel documents, then how many more.
  List<Widget> _missingDocs(AdminOverview data) {
    final flyers = data.flyersMissingDocs;
    if (flyers == null) return const [];
    final total = data.flyersMissingDocsCount ?? flyers.length;
    final shown = flyers.take(3).toList();
    return [
      for (final flyer in shown)
        AttentionRow(
            key: ValueKey('attention-docs-${flyer.name}'),
            icon: Icons.badge_outlined,
            title: tr('{name} is missing {documents}', {
              'name': flyer.name,
              'documents': _documentList(flyer.missing)
            }),
            detail: tr('Flyer documents'),
            onTap: () => _push(FlyerDetailScreen(name: flyer.name))),
      if (total > shown.length)
        AttentionRow(
            key: const Key('attention-docs-more'),
            icon: Icons.groups_2_outlined,
            title: trn(
                total - shown.length,
                '{n} more flyer is missing documents',
                '{n} more flyers are missing documents'),
            onTap: () => _push(const FlyersScreen())),
    ];
  }

  /// The next flight first, then the one after it and any landed flight
  /// that still misses shipment costs.
  List<Widget> _flights(AdminOverview data) {
    final upcoming = [
      for (final flight in data.flights)
        if (flight.status == 'upcoming') flight
    ];
    final missing = [
      for (final flight in data.flights.reversed)
        if (flight.status != 'upcoming' && (flight.missingCostCount ?? 0) > 0)
          flight
    ];
    final main = upcoming.isEmpty ? null : upcoming.first;
    final rest = [...upcoming.skip(1).take(1), ...missing.take(2)];
    if (main == null && rest.isEmpty) {
      return [
        PaperCard(
            onTap: () => _push(const FlightsScreen()),
            child: Row(children: [
              const IconBadge(Icons.flight_rounded, size: 44),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(tr('No upcoming flight'),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    Text(tr('Open the flight list to add a schedule'),
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.muted)),
                  ])),
            ])),
      ];
    }
    return [
      if (main != null)
        _NextFlight(flight: main, onOpen: () => _openFlight(main.code)),
      for (final flight in rest) ...[
        const SizedBox(height: 10),
        _FlightRow(flight: flight, onOpen: () => _openFlight(flight.code)),
      ],
    ];
  }

  Future<void> _add() async {
    final choice = await showAddMenu(context);
    if (!mounted || choice == null) return;
    await _push(switch (choice) {
      AddChoice.shipment => const IntakeScreen(),
      AddChoice.flight => const FlightFormScreen(),
      AddChoice.customer => const CustomerFormScreen(),
      AddChoice.flyer => const FlyerFormScreen(),
      AddChoice.ticket => const TicketImportScreen(),
    });
  }

  void _openFlight(String code) => _push(FlightDetailScreen(code: code));

  void _openShipments() {
    final open = widget.onOpenShipments;
    if (open != null) return open();
    _push(ShipmentsScreen(
        role: UserRole.admin, shipments: AppScope.of(context).shipments));
  }

  void _openFinance() {
    final open = widget.onOpenFinance;
    if (open != null) return open();
    _push(const FinanceScreen());
  }

  Future<void> _push(Widget screen) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) await _load();
  }
}

// ---------------------------------------------------------------------------
// Notices. The server writes them in English; known ones are read so the
// row can be translated and opened, others are shown as sent.

sealed class _Notice {}

class _WeightNotice extends _Notice {
  _WeightNotice(
      {required this.code,
      required this.customer,
      required this.weighed,
      required this.booked});
  final String code, customer, weighed, booked;

  double get _difference =>
      (double.tryParse(weighed) ?? 0) - (double.tryParse(booked) ?? 0);
  bool get over => _difference >= 0;
  String get delta =>
      plainKg(double.parse(_difference.abs().toStringAsFixed(2)));
}

class _FlightNotice extends _Notice {
  _FlightNotice(this.code);
  final String code;
}

class _BillNotice extends _Notice {
  _BillNotice(
      {required this.closes,
      required this.name,
      required this.code,
      required this.amount});
  final String closes, name, code, amount;
}

/// "visa and admission letter" from the server's document kinds.
String _documentList(List<String> kinds) {
  final names = [
    for (final kind in kinds)
      switch (kind) {
        'student_id' => tr('student ID'),
        'visa' => tr('visa'),
        'admission' => tr('admission letter'),
        _ => kind.replaceAll('_', ' '),
      }
  ];
  if (names.isEmpty) return tr('documents');
  if (names.length == 1) return names.single;
  return tr('{list} and {last}', {
    'list': names.sublist(0, names.length - 1).join(', '),
    'last': names.last
  });
}

final _weightText =
    RegExp(r'^(\S+) \((.*)\) weighed ([\d.]+) kg vs ([\d.]+) kg booked');
final _flightText = RegExp(r'^(\S+) departs ');
final _billText = RegExp(
    r'^Billing cycle closes (.+?) — (.+) \(([^()]+)\) balance (\S+) outstanding');

_Notice? _readNotice(OverviewNotice notice) {
  switch (notice.tag) {
    case 'WEIGHT':
      final match = _weightText.firstMatch(notice.text);
      if (match == null) return null;
      final label = match.group(2)!;
      final cut = label.indexOf(' · ');
      return _WeightNotice(
          code: match.group(1)!,
          customer: cut < 0 ? label : label.substring(cut + 3),
          weighed: match.group(3)!,
          booked: match.group(4)!);
    case 'FLIGHT':
      final match = _flightText.firstMatch(notice.text);
      return match == null ? null : _FlightNotice(match.group(1)!);
    case 'DUE':
      final match = _billText.firstMatch(notice.text);
      if (match == null) return null;
      return _BillNotice(
          closes: match.group(1)!,
          name: match.group(2)!,
          code: match.group(3)!,
          amount: match.group(4)!);
  }
  return null;
}

// ---------------------------------------------------------------------------
// Parts.

/// Navy card: cash in hand, then this week's money in and out.
class _MoneyCard extends StatelessWidget {
  const _MoneyCard({required this.data, required this.onFinance});
  final AdminOverview data;
  final VoidCallback onFinance;

  static const _rule = Color(0x24FFFFFF);
  static const _inColor = Color(0xFF6E95DB);
  static const _gain = Color(0xFF9FE0B8);

  @override
  Widget build(BuildContext context) {
    Widget figure(String label, String value, {Color color = Colors.white}) =>
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          WordFitText(label,
              style:
                  const TextStyle(fontSize: 12, height: 1.35, color: heroSoft)),
          FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(value,
                  maxLines: 1,
                  style: TextStyle(
                      fontSize: 15,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: color,
                      fontFeatures: const [FontFeature.tabularFigures()]))),
        ]);
    final net = data.net;
    return Material(
        key: const Key('home-money'),
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(heroRadius),
        clipBehavior: Clip.antiAlias,
        child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(tr('Cash in hand · all accounts'),
                              style: const TextStyle(
                                  fontSize: 13, height: 1.4, color: heroSoft)),
                          FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(wholeBdt(data.cashWorth),
                                  maxLines: 1,
                                  style: const TextStyle(
                                      fontSize: 30,
                                      height: 1.2,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      fontFeatures: [
                                        FontFeature.tabularFigures()
                                      ]))),
                          if (data.cashCny != 0)
                            Text(
                                tr('{bdt} + {cny} at {rate}', {
                                  'bdt': wholeBdt(data.cashBdt),
                                  'cny': wholeMoney(data.cashCny, 'CNY'),
                                  'rate': formatRate(data.rate)
                                }),
                                style: const TextStyle(
                                    fontSize: 12,
                                    height: 1.4,
                                    color: heroSoft)),
                        ])),
                    const SizedBox(width: 8),
                    InkWell(
                        onTap: onFinance,
                        borderRadius: BorderRadius.circular(10),
                        child: ConstrainedBox(
                            constraints: const BoxConstraints(
                                minHeight: minTouchTarget, minWidth: 48),
                            child: Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4),
                                          child: Text(tr('Finance'),
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white))),
                                      const Padding(
                                          padding: EdgeInsets.only(top: 4),
                                          child: Icon(
                                              Icons.chevron_right_rounded,
                                              size: 18,
                                              color: Colors.white)),
                                    ])))),
                  ]),
                  const SizedBox(height: 14),
                  Container(
                      padding: const EdgeInsets.only(top: 12),
                      decoration: const BoxDecoration(
                          border: Border(top: BorderSide(color: _rule))),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(children: [
                              Expanded(
                                  child: Text(tr('This week'),
                                      style: const TextStyle(
                                          fontSize: 13,
                                          height: 1.35,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white))),
                              const SizedBox(width: 8),
                              ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 160),
                                  child: Text(data.weekLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          height: 1.35,
                                          color: heroSoft))),
                            ]),
                            const SizedBox(height: 8),
                            SegmentBar(
                                parts: [
                                  (data.received, _inColor),
                                  (data.expenses, AppColors.accent),
                                ],
                                track: _rule,
                                label: tr('Money in {in}, money out {out}', {
                                  'in': wholeBdt(data.received),
                                  'out': wholeBdt(data.expenses)
                                })),
                            const SizedBox(height: 8),
                            Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                      child: figure(tr('Money in'),
                                          wholeBdt(data.received))),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: figure(tr('Money out'),
                                          wholeBdt(data.expenses))),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: figure(
                                          tr('Net'),
                                          net > 0
                                              ? '+${wholeBdt(net)}'
                                              : wholeBdt(net),
                                          color: net < 0 ? heroAlert : _gain)),
                                ]),
                          ])),
                ])));
  }
}

/// "৳17.50" for the exchange rate.
String formatRate(double rate) => '৳${rate.toStringAsFixed(2)}';

/// Active shipments by where they are: China hub, on a flight, Dhaka hub
/// and out for delivery.
class _StageCard extends StatelessWidget {
  const _StageCard({required this.counts, required this.onOpen});
  final Map<String, int> counts;
  final VoidCallback onOpen;

  int _sum(List<String> statuses) =>
      statuses.fold(0, (sum, status) => sum + (counts[status] ?? 0));

  @override
  Widget build(BuildContext context) {
    final china = _sum(['pending', 'received_cn_hub', 'ready_for_shipment']);
    final flying = _sum(['in_transit', 'customs_cleared']);
    final dhaka = _sum(['received_bd_hub', 'ready_for_last_mile']);
    final delivery = _sum(['out_for_delivery']);
    return PaperCard(
        key: const Key('home-stages'),
        padding: const EdgeInsets.fromLTRB(16, 6, 8, 14),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
                child: Text(tr('Shipments by stage'),
                    style: const TextStyle(
                        fontSize: 15,
                        height: 1.35,
                        fontWeight: FontWeight.w700))),
            TextButton(onPressed: onOpen, child: Text(tr('All'))),
          ]),
          Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SegmentBar(parts: [
                      (china.toDouble(), const Color(0xFFC3D1EC)),
                      (flying.toDouble(), AppColors.primary),
                      (dhaka.toDouble(), AppColors.accent),
                      (delivery.toDouble(), AppColors.ok),
                    ]),
                    const SizedBox(height: 10),
                    FigureRow(figures: [
                      SmallFigure('$china', tr('China hub')),
                      SmallFigure('$flying', tr('On a flight')),
                      SmallFigure('$dhaka', tr('Dhaka hub')),
                      SmallFigure('$delivery', tr('Delivery')),
                    ]),
                  ])),
        ]));
  }
}

String _flyerLine(List<String> flyers) => flyers.isEmpty
    ? tr('Flyer not assigned')
    : trn(flyers.length, 'Flyer {names}', 'Flyers {names}',
        {'names': flyers.join(', ')});

/// Grey or green chip with a money figure, e.g. "Charges ৳11,400".
class _MoneyChip extends StatelessWidget {
  const _MoneyChip(this.label, {this.tone = ChipTone.neutral});
  final String label;
  final ChipTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = tone == ChipTone.neutral
        ? const ToneColors(AppColors.paper, AppColors.inkSoft)
        : toneColors(tone);
    return Container(
        constraints: const BoxConstraints(minHeight: 28),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: colors.background, borderRadius: BorderRadius.circular(8)),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                height: 1.35,
                fontWeight: tone == ChipTone.neutral
                    ? FontWeight.w500
                    : FontWeight.w600,
                color: colors.foreground)));
  }
}

/// The next flight: load, flyers and, when the server sends them, charges
/// and profit so far.
class _NextFlight extends StatelessWidget {
  const _NextFlight({required this.flight, required this.onOpen});
  final OverviewFlight flight;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final day = FlightDay.parse(flight.date);
    final revenue = flight.revenue;
    final profit = flight.profit;
    final missing = flight.missingCostCount ?? 0;
    return PaperCard(
        key: const Key('home-next-flight'),
        onTap: onOpen,
        padding: const EdgeInsets.all(16),
        border: const BorderSide(color: AppColors.primary, width: 1.5),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            DateBlock(day: day, highlight: true),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(displayFlightCode(flight.code),
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.3)),
                  Text(
                      [
                        _flyerLine(flight.flyers),
                        if (day != null) day.relativeLabel,
                      ].join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, height: 1.4, color: AppColors.muted)),
                ])),
            const SizedBox(width: 8),
            StatusPill(label: tr('Up next'), tone: ChipTone.blue),
          ]),
          const SizedBox(height: 12),
          MeterBar(
              value:
                  flight.spaceKg <= 0 ? 0 : flight.bookedKg / flight.spaceKg),
          const SizedBox(height: 6),
          CapacityText(
              booked: flight.bookedKg,
              space: flight.spaceKg,
              extra:
                  '· ${trn(flight.shipmentCount, '{n} shipment', '{n} shipments')}'),
          if (revenue != null || profit != null || missing > 0) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (revenue != null)
                _MoneyChip(
                    tr('Charges {amount}', {'amount': wholeBdt(revenue)})),
              if (profit != null)
                _MoneyChip(
                    tr('Profit so far {amount}', {'amount': wholeBdt(profit)}),
                    tone: profit < 0 ? ChipTone.red : ChipTone.green),
              if (missing > 0)
                FlowChip(
                    label: trn(missing, '{n} shipment missing costs',
                        '{n} shipments missing costs'),
                    icon: Icons.warning_amber_rounded,
                    tone: ChipTone.amber,
                    outlined: true),
            ]),
          ],
        ]));
  }
}

/// A later flight, or a landed one that still misses costs.
class _FlightRow extends StatelessWidget {
  const _FlightRow({required this.flight, required this.onOpen});
  final OverviewFlight flight;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final day = FlightDay.parse(flight.date);
    final missing = flight.missingCostCount ?? 0;
    final upcoming = flight.status == 'upcoming';
    final profit = flight.profit;
    final line = upcoming
        ? '${flight.bookedKg.toStringAsFixed(1)} / ${plainKg(flight.spaceKg)} kg · ${trn(flight.shipmentCount, '{n} shipment', '{n} shipments')}'
        : [
            flight.status == 'departed' ? tr('Departed') : tr('Landed'),
            trn(flight.shipmentCount, '{n} shipment', '{n} shipments'),
            if (profit != null)
              tr('profit {amount}', {'amount': wholeBdt(profit)}),
          ].join(' · ');
    return PaperCard(
        onTap: onOpen,
        padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
        child: Row(children: [
          DateBlock(day: day),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(displayFlightCode(flight.code),
                    style: const TextStyle(
                        fontSize: 15,
                        height: 1.35,
                        fontWeight: FontWeight.w700)),
                Text(line,
                    style: const TextStyle(
                        fontSize: 13, height: 1.4, color: AppColors.muted)),
              ])),
          const SizedBox(width: 8),
          ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: !upcoming && missing > 0
                  ? FlowChip(
                      label:
                          trn(missing, '{n} missing cost', '{n} missing costs'),
                      tone: ChipTone.amber)
                  : StatusPill(
                      label: day?.relativeLabel ?? tr('Upcoming'),
                      tone: ChipTone.blue)),
        ]));
  }
}
