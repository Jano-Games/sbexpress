import 'package:flutter/material.dart';

import '../../data/api/api_exception.dart';
import '../../data/hub/hub_chain.dart';
import '../../data/models/flight.dart';
import '../../data/models/session_user.dart';
import '../../data/models/shipment.dart';
import '../../data/repositories/shipment_repository.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ui.dart';
import '../admin/money_format.dart';
import '../admin/admin_shipment_screen.dart';
import '../intake/intake_screen.dart';
import 'shipment_process_screen.dart';

class ShipmentsScreen extends StatefulWidget {
  const ShipmentsScreen(
      {super.key, required this.role, required this.shipments});

  final UserRole role;
  final ShipmentRepository shipments;

  @override
  State<ShipmentsScreen> createState() => _ShipmentsScreenState();
}

class _ShipmentsScreenState extends State<ShipmentsScreen> {
  final _query = TextEditingController();
  List<OperationalShipment> _hub = const [];
  List<AdminShipment> _admin = const [];
  String? _error;
  var _loading = true;
  var _filter = 'all';

  bool get _isHub => widget.role == UserRole.hub;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      switch (widget.role) {
        case UserRole.hub:
          final rows = await widget.shipments.listHub();
          if (!mounted) return;
          setState(() => _hub = rows);
        case UserRole.admin:
          final rows = await widget.shipments.listAdmin();
          if (!mounted) return;
          setState(() => _admin = rows);
      }
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

  List<OperationalShipment> get _rows => _isHub ? _hub : _admin;

  List<({String value, String label})> get _filters => _isHub
      ? [
          (value: 'all', label: tr('All')),
          (value: 'weigh', label: tr('Weigh')),
          (value: 'pack', label: tr('Pack')),
          (value: 'delivery', label: tr('Delivery')),
          (value: 'moving', label: tr('Incoming')),
          (value: 'delivered', label: tr('Finished')),
        ]
      : [
          (value: 'all', label: tr('All')),
          (value: 'hub', label: tr('At hub')),
          (value: 'moving', label: tr('En route')),
          (value: 'delivered', label: tr('Deliveries')),
        ];

  @override
  Widget build(BuildContext context) {
    final query = _query.text.trim().toLowerCase();
    final visible = _visible(query, _filter);
    final atHub = _hub.where(_atHub).length;
    final moving = _hub.where(_moving).length;
    return WorkspaceScaffold(
        root: true,
        title: tr('Shipments'),
        subtitle: _isHub
            ? tr('{atHub} at Dhaka hub · {moving} incoming',
                {'atHub': atHub, 'moving': moving})
            : tr('From booking to delivery'),
        onRefresh: _load,
        actions: _isHub
            ? null
            : [
                FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primarySoft,
                        foregroundColor: AppColors.primaryInk,
                        minimumSize: const Size(48, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: const StadiumBorder()),
                    icon: const Icon(Icons.add_rounded, size: 19),
                    label: Text(tr('New')),
                    onPressed: () async {
                      await Navigator.of(context).push(MaterialPageRoute<void>(
                          builder: (_) => const IntakeScreen()));
                      if (mounted) await _load();
                    }),
              ],
        toolbar:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(
              controller: _query,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                  hintText: tr('Search code, customer or cargo'),
                  prefixIcon: const Icon(Icons.search_rounded, size: 21),
                  enabledBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                      borderSide: BorderSide(color: AppColors.line)))),
          const SizedBox(height: 4),
          SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(mainAxisAlignment: MainAxisAlignment.start, children: [
                for (final option in _filters) ...[
                  _FilterChip(
                      label: option.label,
                      count: _rows.isEmpty
                          ? null
                          : _visible(query, option.value).length,
                      dot: option.value == 'weigh',
                      selected: _filter == option.value,
                      onTap: () => setState(() => _filter = option.value)),
                  const SizedBox(width: 8),
                ]
              ])),
        ]),
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) ErrorNote(message: _error!, onRetry: _load),
          if (!_loading && _error == null && visible.isEmpty)
            EmptyNote(
                icon: Icons.search_off_rounded,
                title: tr('No shipments found'),
                body: tr('Try another word or filter.')),
          if (visible.isNotEmpty)
            ...(_isHub ? _hubGroups(visible) : _adminList(visible)),
        ]);
  }

  List<Widget> _hubGroups(List<OperationalShipment> visible) {
    final groups = <(String, List<OperationalShipment>)>[
      (
        tr('Processing at hub'),
        [
          for (final row in visible)
            if (hubListStep(row) == HubListStep.weigh ||
                hubListStep(row) == HubListStep.pack)
              row
        ]
      ),
      (
        tr('Ready for delivery'),
        [
          for (final row in visible)
            if (hubListStep(row) == HubListStep.deliveryChain) row
        ]
      ),
      (
        tr('Incoming'),
        [
          for (final row in visible)
            if (_moving(row)) row
        ]
      ),
      (
        tr('Other'),
        [
          for (final row in visible)
            if (hubListStep(row) == HubListStep.none && !_moving(row)) row
        ]
      ),
    ];
    return [
      for (final (title, rows) in groups)
        if (rows.isNotEmpty) ...[
          _GroupHeader(title: title, count: rows.length),
          for (final row in rows) ...[
            _HubCard(row: row, onOpen: () => _open(row)),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 6),
        ]
    ];
  }

  List<Widget> _adminList(List<OperationalShipment> visible) => [
        _GroupHeader(title: tr('Shipments'), count: visible.length),
        SurfaceGroup(children: [
          for (final row in visible)
            _AdminRow(row: row, onOpen: () => _open(row)),
        ]),
      ];

  List<OperationalShipment> _visible(String query, String filter) => [
        for (final row in _rows)
          if (_matchesFilter(row, filter) &&
              (query.isEmpty ||
                  row.code.toLowerCase().contains(query) ||
                  row.supplierCode.toLowerCase().contains(query) ||
                  row.description.toLowerCase().contains(query) ||
                  (row is AdminShipment &&
                      (row.supplierName ?? '').toLowerCase().contains(query))))
            row,
      ];

  static bool _atHub(OperationalShipment row) =>
      row.status == 'received_bd_hub' ||
      row.status == 'ready_for_last_mile' ||
      row.status == 'out_for_delivery';

  static bool _moving(OperationalShipment row) =>
      row.status == 'received_cn_hub' ||
      row.status == 'ready_for_shipment' ||
      row.status == 'in_transit' ||
      row.status == 'customs_cleared';

  bool _matchesFilter(OperationalShipment row, String filter) {
    switch (filter) {
      case 'hub':
        return _atHub(row);
      case 'weigh':
        return hubListStep(row) == HubListStep.weigh;
      case 'pack':
        return hubListStep(row) == HubListStep.pack;
      case 'delivery':
        return hubListStep(row) == HubListStep.deliveryChain;
      case 'moving':
        return _moving(row);
      case 'delivered':
        return row.status == 'delivered';
      default:
        return true;
    }
  }

  void _open(OperationalShipment row) {
    final screen = switch (widget.role) {
      UserRole.hub => ShipmentProcessScreen(code: row.code),
      UserRole.admin => AdminShipmentScreen(code: row.code),
    };
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screen))
        .then((_) {
      if (mounted) _load();
    });
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip(
      {required this.label,
      required this.count,
      required this.selected,
      required this.onTap,
      this.dot = false});
  final String label;
  final int? count;
  final bool selected, dot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
      button: true,
      selected: selected,
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
              constraints: const BoxConstraints(minHeight: minTouchTarget),
              alignment: Alignment.center,
              child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                      color: selected ? AppColors.primary : AppColors.card,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color:
                              selected ? AppColors.primary : AppColors.field)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (dot && !selected) ...[
                      Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                              color: AppColors.accent, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                    ],
                    Text(label,
                        style: TextStyle(
                            fontSize: 14,
                            height: 1.3,
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.w500,
                            color:
                                selected ? Colors.white : AppColors.inkSoft)),
                    if (count != null) ...[
                      const SizedBox(width: 6),
                      Text('$count',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? const Color(0xD9FFFFFF)
                                  : AppColors.muted)),
                    ],
                  ])))));
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.title, required this.count});
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Row(children: [
        Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkSoft))),
        Text(tr('{n}', {'n': count}),
            style: const TextStyle(fontSize: 13, color: AppColors.muted)),
      ]));
}

/// Hub card: what it is, where it came from and which step is next.
class _HubCard extends StatelessWidget {
  const _HubCard({required this.row, required this.onOpen});
  final OperationalShipment row;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final step = hubListStep(row);
    final delta = row.weightDelta;
    final (done, next) = switch (step) {
      HubListStep.weigh => (0, tr('Weigh')),
      HubListStep.pack => (1, tr('Pack')),
      HubListStep.deliveryChain => (2, tr('Courier')),
      HubListStep.none => (0, null),
    };
    final kgLabel = row.weighedKg == null
        ? tr('Booked {kg}', {'kg': formatKg(row.bookedKg)})
        : tr('Weighed {kg}', {'kg': formatKg(row.weighedKg!)});
    return PaperCard(
        onTap: onOpen,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(row.code,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700))),
            const SizedBox(width: 8),
            Flexible(
                child: Align(
                    alignment: Alignment.centerRight,
                    child: StatusPill(
                        label: banglaStatus(row.status, row.statusLabel),
                        tone: shipmentStatusTone(row.statusIndex)))),
          ]),
          Text(
              [
                if (row.description.isNotEmpty) row.description,
                tr('Customer {code}', {'code': row.supplierCode})
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, color: AppColors.muted)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            InfoChip(icon: Icons.scale_outlined, label: kgLabel),
            if (delta != null)
              InfoChip(
                  icon: Icons.warning_amber_rounded,
                  label: delta > 0
                      ? tr('{delta} kg over',
                          {'delta': '+${delta.toStringAsFixed(1)}'})
                      : tr('{delta} kg under',
                          {'delta': delta.toStringAsFixed(1)}),
                  tone: ChipTone.red),
            if (row.flightCode != null)
              InfoChip(
                  icon: Icons.flight_outlined,
                  label: [
                    displayFlightCode(row.flightCode!),
                    if (row.flightDate != null) _shortDate(row.flightDate!)
                  ].join(' · ')),
          ]),
          if (next != null) ...[
            const Divider(height: 24),
            StepBars(done: done, height: 6),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: Text.rich(
                      TextSpan(
                          text:
                              tr('Step {step}/5 · next: ', {'step': done + 1}),
                          children: [
                            TextSpan(
                                text: next,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.accentInk)),
                          ]),
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.muted))),
              Text(tr('Open'),
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary)),
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: AppColors.primary),
            ]),
          ],
        ]));
  }
}

class _AdminRow extends StatelessWidget {
  const _AdminRow({required this.row, required this.onOpen});
  final OperationalShipment row;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final current = row;
    final name = current is AdminShipment ? current.supplierName : null;
    final due = current is AdminShipment ? current.dueAmount : 0.0;
    return InkWell(
        onTap: onOpen,
        child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              const IconBadge(Icons.inventory_2_outlined,
                  tone: ChipTone.neutral),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      Expanded(
                          child: Text(row.code,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700))),
                      const SizedBox(width: 8),
                      Flexible(
                          child: Align(
                              alignment: Alignment.centerRight,
                              child: StatusPill(
                                  label:
                                      banglaStatus(row.status, row.statusLabel),
                                  tone: shipmentStatusTone(row.statusIndex)))),
                    ]),
                    const SizedBox(height: 2),
                    Text(
                        [
                          name == null || name.isEmpty
                              ? row.supplierCode
                              : name,
                          formatKg(row.effectiveKg),
                          if (row.description.isNotEmpty) row.description,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.muted)),
                    if (due > 0) ...[
                      const SizedBox(height: 2),
                      Text(tr('Due {amount}', {'amount': formatBdt(due)}),
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accentInk)),
                    ],
                  ])),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: AppColors.faint),
            ])));
  }
}

const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

String _shortDate(String iso) {
  final date = DateTime.tryParse(iso);
  if (date == null) return iso;
  return '${date.day} ${_monthNames[date.month - 1]}';
}
