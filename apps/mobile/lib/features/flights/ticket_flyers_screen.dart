import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/flight.dart';
import '../../data/models/flyer.dart';
import '../../data/models/hub_flight.dart';
import '../../data/money_payload.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/finance_parts.dart' show showChoiceSheet;
import '../../widgets/flight_parts.dart'
    show
        ActionNote,
        AccentOutlineButton,
        LetterAvatar,
        RowCard,
        isClockTime,
        stopText;
import '../../widgets/flow_parts.dart';
import '../../widgets/ui.dart';
import '../admin/money_format.dart';
import 'flight_money_screen.dart';
import 'hub_flights_screen.dart' show banglaPlace;

/// The flight's ticket: who flies, what the ticket cost and who pays it.
class TicketFlyersScreen extends StatefulWidget {
  const TicketFlyersScreen({super.key, required this.code});

  final String code;

  @override
  State<TicketFlyersScreen> createState() => _TicketFlyersScreenState();
}

class _TicketFlyersScreenState extends State<TicketFlyersScreen> {
  FlightDetail? _detail;
  List<FlyerSummary> _flyers = const [];
  final _cost = TextEditingController();
  final _parts = <String, TextEditingController>{};
  var _flyersPay = false;
  var _ready = false;
  String? _error;
  var _loading = true;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _cost.dispose();
    for (final field in _parts.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final scope = AppScope.of(context);
      final detail = await scope.flights.detail(widget.code);
      final flyers = await scope.flyers.list();
      if (!mounted) return;
      final summary = detail.summary;
      if (!_ready) {
        _cost.text = summary.actualCost > 0 ? _plain(summary.actualCost) : '';
        final split = summary.settlements
            .fold(0.0, (total, row) => total + row.contribution);
        _flyersPay = summary.flyersShare > 0.001 || split > 0.001;
        _ready = true;
      }
      for (final name in summary.flyers) {
        _parts.putIfAbsent(name, () {
          final saved = _settlement(summary, name)?.contribution ?? 0;
          return TextEditingController(text: saved > 0 ? _plain(saved) : '');
        });
      }
      for (final name in _parts.keys.toList()) {
        if (!summary.flyers.contains(name)) _parts.remove(name)?.dispose();
      }
      setState(() {
        _detail = detail;
        _flyers = flyers;
      });
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

  FlyerSummary? _profile(String name) {
    for (final flyer in _flyers) {
      if (flyer.name == name) return flyer;
    }
    return null;
  }

  /// The flyer's Bangladesh phone from the flight, when it is a number.
  String? _phone(String name) {
    for (final flyer in _detail?.flyerDetails ?? const <FlyerOnFlight>[]) {
      if (flyer.name == name && RegExp(r'\d{5,}').hasMatch(flyer.bdPhone)) {
        return flyer.bdPhone;
      }
    }
    return null;
  }

  double get _typedCost => readOptionalMoney(_cost.text) ?? 0;

  double _typedPart(String name) =>
      _flyersPay ? (readOptionalMoney(_parts[name]?.text ?? '') ?? 0) : 0;

  double _typedFlyers(FlightSummary summary) => roundMoney(
      summary.flyers.fold(0.0, (total, name) => total + _typedPart(name)));

  /// Typed values differ from what is saved, so payments wait for Save.
  bool _dirty(FlightSummary summary) {
    if ((_typedCost - summary.actualCost).abs() > 0.001) return true;
    if ((roundMoney(_typedCost - _typedFlyers(summary)) - summary.agencyShare)
            .abs() >
        0.001) {
      return true;
    }
    for (final name in summary.flyers) {
      final saved = _settlement(summary, name)?.contribution ?? 0;
      if ((_typedPart(name) - saved).abs() > 0.001) return true;
    }
    return false;
  }

  Future<void> _addFlyer(FlightSummary summary) async {
    final free = [
      for (final flyer in _flyers)
        if (!flyer.archived && !summary.flyers.contains(flyer.name)) flyer.name
    ];
    if (free.isEmpty) {
      setState(() => _error = tr('No active flyers left to add.'));
      return;
    }
    final name = await showChoiceSheet(context,
        title: tr('Add flyer'),
        options: [for (final name in free) (value: name, label: name)],
        selected: '');
    if (name == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await AppScope.of(context).flights.assignFlyer(widget.code, name);
      await _load();
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeFlyer(String name) async {
    setState(() => _busy = true);
    try {
      await AppScope.of(context).flights.removeFlyer(widget.code, name);
      await _load();
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(Widget screen) async {
    final saved = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => screen));
    if (saved == true && mounted) await _load();
  }

  Future<void> _save() async {
    final summary = _detail?.summary;
    if (summary == null) return;
    final cost = readOptionalMoney(_cost.text);
    if (cost == null) {
      setState(() => _error =
          tr('Enter the ticket cost as a number with up to two decimals.'));
      return;
    }
    final flyers = summary.flyers;
    final parts = <String, double>{};
    for (final name in flyers) {
      final part =
          _flyersPay ? readOptionalMoney(_parts[name]?.text ?? '') : 0.0;
      if (part == null) {
        setState(() => _error = tr('Enter 0 or more for each flyer.'));
        return;
      }
      parts[name] = part;
    }
    if (_flyersPay && flyers.isEmpty) {
      setState(() => _error = tr('Add flyers to the flight first.'));
      return;
    }
    final flyersTotal =
        roundMoney(parts.values.fold(0.0, (total, part) => total + part));
    if (flyersTotal > cost + 0.001) {
      setState(() =>
          _error = tr("The flyers' parts add up to more than the ticket."));
      return;
    }
    final earlier = summary.unallocatedFlyerPaid;
    if (earlier > 0 && flyers.length > 1) {
      setState(() => _error = tr(
          'Assign the earlier {amount} in Split contributions first.',
          {'amount': formatBdt(earlier)}));
      return;
    }
    for (final name in flyers) {
      final paid = (_settlement(summary, name)?.paidAmount ?? 0) +
          (flyers.length == 1 ? earlier : 0);
      if (parts[name]! < paid - 0.001) {
        setState(() => _error = tr(
            '{name} has already paid {amount}, so their part cannot be lower.',
            {'name': name, 'amount': formatBdt(paid)}));
        return;
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final flights = AppScope.of(context).flights;
      await flights.updateTicket(widget.code,
          actualCost: cost, agencyShare: roundMoney(cost - flyersTotal));
      if (flyers.isNotEmpty) {
        await flights.allocateContributions(widget.code, [
          for (final name in flyers)
            (
              name: name,
              contribution: parts[name]!,
              legacyPaid: flyers.length == 1 ? earlier : 0.0
            ),
        ]);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _detail?.summary;
    return WorkspaceScaffold(
        title: tr('Ticket and flyers'),
        subtitle: _flightLine(summary, widget.code),
        root: false,
        onRefresh: _load,
        footer: ActionFooter(
            child: AppButton(
                key: const Key('ticket-save'),
                label: tr('Save'),
                icon: Icons.check_rounded,
                kind: AppButtonKind.current,
                busy: _busy,
                onPressed: summary == null ? null : _save)),
        children: [
          if (_loading && summary == null) const LinearProgressIndicator(),
          if (_error != null) ErrorNote(message: _error!),
          if (summary != null) ...[
            _FlightCard(summary: summary),
            const SizedBox(height: 16),
            SectionTitle(
                title: tr('Flyers · {n}', {'n': summary.flyers.length}),
                action: TextButton.icon(
                    onPressed: _busy ? null : () => _addFlyer(summary),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(tr('Add flyer')))),
            if (summary.flyers.isEmpty)
              EmptyNote(
                  icon: Icons.person_outline_rounded,
                  title: tr('No flyers'),
                  body: tr('Add the flyers who carry cargo on this ticket.'))
            else
              RowCard(children: [
                for (var i = 0; i < summary.flyers.length; i++)
                  _FlyerRow(
                      name: summary.flyers[i],
                      profile: _profile(summary.flyers[i]),
                      phone: _phone(summary.flyers[i]),
                      flight: summary.displayCode,
                      first: i == 0,
                      onRemove:
                          _busy ? null : () => _removeFlyer(summary.flyers[i])),
              ]),
            const SizedBox(height: 16),
            _ticketCard(summary),
            const SizedBox(height: 16),
            _paymentsCard(summary),
          ],
        ]);
  }

  Widget _ticketCard(FlightSummary summary) {
    final cost = _typedCost;
    final flyers = _typedFlyers(summary);
    final ours = roundMoney(cost - flyers);
    final unsplit = roundMoney(summary.flyersShare -
        summary.settlements
            .fold(0.0, (total, row) => total + row.contribution));
    return PaperCard(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _label(tr('Ticket cost')),
      BigAmountField(
          key: const Key('ticket-cost'),
          controller: _cost,
          suffix: 'BDT',
          onChanged: (_) => setState(() {})),
      const Divider(height: 28, color: AppColors.lineSoft),
      Text(tr('Who pays the ticket?'),
          style: const TextStyle(
              fontSize: 17, fontWeight: FontWeight.w700, height: 1.35)),
      const SizedBox(height: 10),
      ChoicePair(
          first: BigChoice(
              key: const Key('ticket-we-pay'),
              icon: Icons.apartment_rounded,
              title: tr('We pay all'),
              subtitle: tr('Our company pays the whole ticket'),
              selected: !_flyersPay,
              onTap: () => setState(() => _flyersPay = false)),
          second: BigChoice(
              key: const Key('ticket-flyers-pay'),
              icon: Icons.groups_2_outlined,
              title: tr('Flyers pay part'),
              subtitle: tr('Each flyer pays a part, we pay the rest'),
              selected: _flyersPay,
              onTap: () => setState(() => _flyersPay = true))),
      if (_flyersPay) ...[
        const SizedBox(height: 14),
        Text(tr("Each flyer's part"),
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.inkSoft)),
        if (summary.flyers.isEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(tr('Add flyers to the flight first.'),
                  style: const TextStyle(color: AppColors.muted, height: 1.45)))
        else
          for (var i = 0; i < summary.flyers.length; i++)
            Padding(
                padding: const EdgeInsets.only(top: 10),
                child: LayoutBuilder(
                    builder: (context, box) => Row(children: [
                          LetterAvatar(summary.flyers[i],
                              size: 32,
                              color: i == 0
                                  ? AppColors.primary
                                  : AppColors.inkSoft),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(summary.flyers[i],
                                  style: const TextStyle(
                                      fontSize: 15,
                                      height: 1.3,
                                      fontWeight: FontWeight.w600))),
                          const SizedBox(width: 8),
                          SizedBox(
                              width: box.maxWidth * 0.42 > 150
                                  ? 150
                                  : box.maxWidth * 0.42,
                              child: BigAmountField(
                                  key: ValueKey('part-${summary.flyers[i]}'),
                                  controller: _parts[summary.flyers[i]]!,
                                  fontSize: 17,
                                  textAlign: TextAlign.end,
                                  onChanged: (_) => setState(() {}))),
                        ]))),
        if (unsplit > 0.001) ...[
          const SizedBox(height: 12),
          ActionNote(
              text: tr(
                  '{amount} of the ticket is not split between the flyers yet.',
                  {'amount': formatBdt(unsplit)})),
        ],
      ],
      if (summary.unallocatedFlyerPaid > 0 && summary.flyers.length > 1) ...[
        const SizedBox(height: 12),
        ActionNote(
            text: tr(
                '{amount} was received before the split and is not assigned to a flyer yet. Assign it once in the split.',
                {
                  'amount': formatBdt(summary.unallocatedFlyerPaid)
                }),
            action: AccentOutlineButton(
                label: tr('Split contributions'),
                icon: Icons.call_split_rounded,
                onPressed: () => _open(ContributionScreen(code: widget.code)))),
      ],
      if (cost > 0) ...[
        const SizedBox(height: 14),
        SplitSummary(
            ours: ours < 0 ? 0 : ours,
            flyers: flyers,
            ticket: cost,
            problem: ours < -0.001
                ? tr("The flyers' parts add up to more than the ticket.")
                : null),
      ],
    ]));
  }

  Widget _paymentsCard(FlightSummary summary) {
    final share = summary.flyersShare;
    final received = roundMoney(
        summary.settlements.fold(0.0, (total, row) => total + row.paidAmount) +
            summary.unallocatedFlyerPaid);
    // Flyer payments follow the saved split; the seller only the saved cost.
    final dirty = _dirty(summary);
    final costDirty = (_typedCost - summary.actualCost).abs() > 0.001;
    Widget heading(String title, String action, IconData icon,
            VoidCallback onTap, Key key, bool locked) =>
        Row(children: [
          Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 14,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkSoft))),
          TextButton.icon(
              key: key,
              onPressed: locked ? null : onTap,
              style: TextButton.styleFrom(
                  minimumSize: const Size(48, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 4)),
              icon: Icon(icon, size: 16),
              label: Text(action)),
        ]);
    return PaperCard(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(tr('Payments so far'),
          style: const TextStyle(
              fontSize: 17, fontWeight: FontWeight.w700, height: 1.3)),
      Text(tr('Money in from flyers and out to the ticket seller'),
          style: const TextStyle(
              fontSize: 13, color: AppColors.muted, height: 1.4)),
      if (dirty)
        Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(tr('Save the changes first to record payments.'),
                style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentInk))),
      const SizedBox(height: 10),
      heading(
          tr('Flyers paid us'),
          tr('Record flyer payment'),
          Icons.south_west_rounded,
          () => _open(FlyerPaymentScreen(code: widget.code)),
          const Key('ticket-flyer-payment'),
          dirty),
      if (share <= 0.001 && received <= 0)
        Text(tr('We pay the whole ticket, so no flyer pays.'),
            style: const TextStyle(
                fontSize: 13, height: 1.45, color: AppColors.muted))
      else ...[
        MoneyProgress(
            done: received,
            total: share,
            left: tr('{amount} left', {'amount': formatBdt(summary.flyerDue)})),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final name in summary.flyers) _flyerChip(summary, name),
        ]),
      ],
      const Divider(height: 28, color: AppColors.lineSoft),
      heading(
          tr('We paid the ticket seller'),
          tr('Pay ticket'),
          Icons.north_east_rounded,
          () => _open(TicketSettleScreen(code: widget.code)),
          const Key('ticket-pay-seller'),
          costDirty),
      MoneyProgress(
          done: summary.ticketPaid,
          total: summary.actualCost,
          color: AppColors.inkSoft,
          left: summary.ticketRefundDue > 0
              ? tr('{amount} refund due',
                  {'amount': formatBdt(summary.ticketRefundDue)})
              : tr('{amount} left to pay',
                  {'amount': formatBdt(summary.ticketDue)})),
    ]));
  }

  Widget _flyerChip(FlightSummary summary, String name) {
    final row = _settlement(summary, name);
    final first = name.trim().split(RegExp(r'\s+')).first;
    if (row == null || row.contribution <= 0) {
      return FlowChip(label: tr('{name} · no part', {'name': first}));
    }
    if (row.due <= 0) {
      return FlowChip(
          label: tr('{name} · paid up', {'name': first}), tone: ChipTone.green);
    }
    return FlowChip(
        label: tr('{name} · {left} left of {part}', {
          'name': first,
          'left': formatBdt(row.due),
          'part': formatBdt(row.contribution)
        }),
        tone: ChipTone.amber);
  }

  Widget _label(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 2),
      child: Text(text,
          style: const TextStyle(
              fontSize: 13, height: 1.35, fontWeight: FontWeight.w600)));
}

FlightSettlement? _settlement(FlightSummary summary, String name) {
  for (final row in summary.settlements) {
    if (row.name == name) return row;
  }
  return null;
}

/// "BG305 · Wednesday 21 Oct".
String _flightLine(FlightSummary? summary, String code) {
  if (summary == null) return displayFlightCode(code);
  final day = FlightDay.parse(summary.date);
  return [
    summary.displayCode,
    if (day != null) '${day.weekdayName} ${day.day} ${day.month}'
  ].join(' · ');
}

/// "Chengdu 09:40 → Dhaka 12:10 · Direct", with the arrow drawn as an icon
/// because the app font has no arrow.
InlineSpan routeSpan(FlightSummary summary) {
  String end(String place, String time) =>
      isClockTime(time) ? '$place $time' : place;
  return TextSpan(children: [
    TextSpan(
        text: end(
            banglaPlace(summary.from, fallback: tr('China')), summary.depTime)),
    const WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Icon(Icons.arrow_forward_rounded,
                size: 14, color: AppColors.muted))),
    TextSpan(
        text:
            '${end(banglaPlace(summary.to, fallback: tr('Dhaka')), summary.arrTime)} · ${stopText(summary.stopLabel)}'),
  ]);
}

/// 42000 rather than 42000.0 in an amount field.
String _plain(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(2);

class _FlightCard extends StatelessWidget {
  const _FlightCard({required this.summary});
  final FlightSummary summary;

  @override
  Widget build(BuildContext context) {
    final day = FlightDay.parse(summary.date);
    return PaperCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(children: [
          const IconBadge(Icons.flight_rounded),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                          [
                            summary.displayCode,
                            if (day != null) '${day.day} ${day.month}'
                          ].join(' · '),
                          style: const TextStyle(
                              fontSize: 15,
                              height: 1.35,
                              fontWeight: FontWeight.w700)),
                      if (summary.fromTicket)
                        FlowChip(
                            label: tr('From e-ticket'),
                            icon: Icons.task_outlined,
                            tone: ChipTone.green),
                    ]),
                Text.rich(routeSpan(summary),
                    style: const TextStyle(
                        fontSize: 13, height: 1.4, color: AppColors.muted)),
              ])),
        ]));
  }
}

class _FlyerRow extends StatelessWidget {
  const _FlyerRow(
      {required this.name,
      required this.profile,
      required this.phone,
      required this.flight,
      required this.first,
      required this.onRemove});
  final String name;
  final FlyerSummary? profile;
  final String? phone;
  final String flight;
  final bool first;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final person = profile;
    final number = person != null && person.bdPhone.trim().isNotEmpty
        ? person.bdPhone
        : phone;
    final line = [
      if (number != null) number,
      if (person != null && person.university.trim().isNotEmpty)
        person.university,
    ].join(' · ');
    return Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
        child: Row(children: [
          LetterAvatar(name,
              color: first ? AppColors.primary : AppColors.inkSoft),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 15,
                        height: 1.35,
                        fontWeight: FontWeight.w600)),
                if (line.isNotEmpty)
                  Text(line,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, height: 1.4, color: AppColors.muted)),
              ])),
          IconButton(
              tooltip: tr('Remove {name} from {flight}',
                  {'name': name, 'flight': flight}),
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded,
                  size: 19, color: AppColors.muted)),
        ]));
  }
}
