import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/hub_flight.dart';
import '../../data/models/sorting.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ui.dart';
import 'approve_customer_screen.dart';
import 'sort_parts.dart';

/// Every customer the hub sorted, waiting for the admin, by flight.
class ApprovalsScreen extends StatefulWidget {
  const ApprovalsScreen({super.key});

  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen> {
  Approvals? _data;
  String? _error;
  var _loading = true;
  String? _approving;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await AppScope.of(context).sorting.approvals();
      if (mounted) setState(() => _data = data);
    } on ApiException catch (error) {
      if (mounted && error.status != 401) {
        setState(() => _error = error.message);
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approveAll(ApprovalFlight flight) async {
    final n = flight.groups.length;
    final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(
                  trn(n, 'Approve {n} customer?', 'Approve {n} customers?')),
              content: Text(tr(
                  'Courier orders go In delivery and Hub pickup orders become ready for pickup. The hub gets a notification for each.')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(tr('Cancel'))),
                FilledButton(
                    key: const Key('approve-all-confirm'),
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(tr('Approve all'))),
              ],
            ));
    if (yes != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _approving = flight.flight.code);
    try {
      final result =
          await AppScope.of(context).sorting.approveAll(flight.flight.code);
      messenger.showSnackBar(SnackBar(
          content: Text(trn(result.orders.length, '{n} order approved',
              '{n} orders approved'))));
      if (mounted) await _load();
    } on ApiException catch (error) {
      if (error.status != 401) {
        messenger.showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _approving = null);
    }
  }

  Future<void> _open(ApprovalFlight flight, SortGroup group) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ApproveCustomerScreen(
            flightCode: flight.flight.code, customer: group.customerCode)));
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final customers =
        data?.flights.fold<int>(0, (n, f) => n + f.groups.length) ?? 0;
    return WorkspaceScaffold(
      title: tr('Waiting for approval'),
      subtitle: data == null
          ? null
          : '${trn(customers, '{n} customer', '{n} customers')} · ${trn(data.flights.length, '{n} flight', '{n} flights')}',
      onRefresh: _load,
      children: [
        if (_loading && data == null) const LinearProgressIndicator(),
        if (_error != null) ErrorNote(message: _error!, onRetry: _load),
        if (data != null && data.flights.isEmpty)
          EmptyNote(
              icon: Icons.task_alt_rounded,
              title: tr('Nothing waiting'),
              body: tr(
                  'When the hub sorts a customer, it shows up here for you to check.')),
        if (data != null)
          for (final flight in data.flights) ...[
            _FlightHead(
                flight: flight,
                busy: _approving == flight.flight.code,
                onApproveAll: () => _approveAll(flight)),
            for (final g in flight.groups) ...[
              _ApprovalCard(group: g, onTap: () => _open(flight, g)),
              const SizedBox(height: 10),
            ],
            if (flight.groups.any((g) => g.needsLook)) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
                child: Text(
                    tr(
                        'Approve all works when no customer needs a look. {names} weighs more or less than booked.',
                        {
                          'names': flight.groups
                              .where((g) => g.needsLook)
                              .map((g) => g.who)
                              .join(', ')
                        }),
                    style: const TextStyle(
                        fontSize: 12.5, height: 1.45, color: AppColors.muted)),
              ),
            ],
            const SizedBox(height: 22),
          ],
      ],
    );
  }
}

class _FlightHead extends StatelessWidget {
  const _FlightHead(
      {required this.flight, required this.busy, required this.onApproveAll});

  final ApprovalFlight flight;
  final bool busy;
  final VoidCallback onApproveAll;

  @override
  Widget build(BuildContext context) {
    final day = FlightDay.parse(flight.flight.date);
    final by = {
      for (final g in flight.groups)
        if (g.sortedBy != null) g.sortedBy!
    }.join(', ');
    final n = flight.groups.length;
    final blocked = flight.groups.any((g) => g.needsLook);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 10),
      child: Row(children: [
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                day == null
                    ? flight.flight.number
                    : '${flight.flight.number} · ${day.shortLabel}',
                style: const TextStyle(
                    fontSize: 16.5, fontWeight: FontWeight.w700)),
            Text(
                by.isEmpty
                    ? trn(n, '{n} customer sorted', '{n} customers sorted')
                    : trn(n, '{n} customer sorted by {by}',
                        '{n} customers sorted by {by}', {'by': by}),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
          ]),
        ),
        const SizedBox(width: 10),
        FilledButton(
            key: Key('approve-all-${flight.flight.code}'),
            onPressed: blocked || busy ? null : onApproveAll,
            child: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(tr('Approve all'))),
      ]),
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({required this.group, required this.onTap});

  final SortGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = group;
    final photos = g.orders.fold<int>(0, (n, o) => n + o.goodsPhotos.length) +
        g.packingPhotos.length;
    final partner = g.partner == null
        ? tr('No partner')
        : g.pickup
            ? tr('Hub pickup')
            : g.partner!;
    final pill = g.needsLook
        ? StatusPill(
            label: tr('{diff}, check',
                {'diff': weightPill(g.measuredKg, g.bookedKg)}),
            tone: ChipTone.amber)
        : StatusPill(
            label: weightPill(g.measuredKg, g.bookedKg),
            tone: (g.measuredKg - g.bookedKg).abs() < 0.05
                ? ChipTone.green
                : ChipTone.blue);
    return PaperCard(
      key: Key('approval-${g.customerCode}'),
      onTap: onTap,
      border: g.needsLook
          ? const BorderSide(color: AppColors.accentLine, width: 1.5)
          : null,
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CustomerMark(name: g.who, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(g.who,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15.5, fontWeight: FontWeight.w700)),
              Text(
                  [
                    trn(g.orders.length, '{n} order', '{n} orders'),
                    if (g.sortedAt != null)
                      tr('sorted {when}', {'when': whenText(g.sortedAt!)}),
                  ].join(' · '),
                  style:
                      const TextStyle(fontSize: 12.5, color: AppColors.muted)),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded,
              size: 20, color: AppColors.faint),
        ]),
        const SizedBox(height: 10),
        Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                  tr('{booked} booked · {measured} measured', {
                    'booked': kgText(g.bookedKg),
                    'measured': kgText(g.measuredKg)
                  }),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              pill,
            ]),
        const SizedBox(height: 8),
        Row(children: [
          Icon(
              g.pickup
                  ? Icons.storefront_outlined
                  : Icons.local_shipping_outlined,
              size: 15,
              color: AppColors.muted),
          const SizedBox(width: 5),
          Flexible(
            child: Text(partner,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.image_outlined, size: 15, color: AppColors.muted),
          const SizedBox(width: 5),
          Text(trn(photos, '{n} photo', '{n} photos'),
              style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
        ]),
      ]),
    );
  }
}
