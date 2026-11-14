import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/hub_flight.dart';
import '../../data/models/session_user.dart';
import '../../data/models/sorting.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ui.dart';
import 'approve_customer_screen.dart';
import 'sort_customer_screen.dart';
import 'sort_parts.dart';

/// A flight's orders at the Dhaka hub, one row per customer. The hub opens a
/// customer to sort it; the admin opens it to check and approve.
class SortFlightScreen extends StatefulWidget {
  const SortFlightScreen({super.key, required this.flightCode});

  final String flightCode;

  @override
  State<SortFlightScreen> createState() => _SortFlightScreenState();
}

class _SortFlightScreenState extends State<SortFlightScreen> {
  SortBoard? _board;
  String? _error;
  var _loading = true;

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
      final board = await AppScope.of(context).sorting.board(widget.flightCode);
      if (mounted) setState(() => _board = board);
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

  Future<void> _open(SortGroup group) async {
    final admin = AppScope.of(context).session.user?.role == UserRole.admin;
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => admin
            ? ApproveCustomerScreen(
                flightCode: widget.flightCode, customer: group.customerCode)
            : SortCustomerScreen(
                flightCode: widget.flightCode, customer: group.customerCode)));
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final board = _board;
    final day = board == null ? null : FlightDay.parse(board.flight.date);
    final received =
        board?.groups.where((g) => g.state != SortState.notReceived).toList() ??
            const <SortGroup>[];
    return WorkspaceScaffold(
      title: board?.flight.number ?? widget.flightCode,
      subtitle: day == null
          ? null
          : received.isEmpty
              ? day.shortLabel
              : tr('{day} · received', {'day': day.shortLabel}),
      onRefresh: _load,
      children: [
        if (_loading && board == null) const LinearProgressIndicator(),
        if (_error != null) ErrorNote(message: _error!, onRetry: _load),
        if (board != null) ...[
          _Summary(board: board),
          const SizedBox(height: 22),
          SectionTitle(
              title: tr('Sort by customer'),
              action: Text(
                  trn(board.groups.length, '{n} customer', '{n} customers'),
                  style:
                      const TextStyle(fontSize: 13, color: AppColors.muted))),
          if (board.groups.isEmpty)
            EmptyNote(
                icon: Icons.inventory_2_outlined,
                title: tr('No orders on this flight'),
                body: tr('Orders appear here once booked.'))
          else
            SurfaceGroup(children: [
              for (final g in board.groups)
                _CustomerRow(group: g, onTap: () => _open(g)),
            ]),
        ],
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.board});

  final SortBoard board;

  @override
  Widget build(BuildContext context) {
    final orders = board.groups.fold<int>(0, (n, g) => n + g.orders.length);
    final kg = board.groups.fold<double>(0, (n, g) => n + g.bookedKg);
    final atHub = board.groups.where((g) => g.state != SortState.notReceived);
    final counts = [
      (SortState.toSort, board.count(SortState.toSort)),
      (SortState.sentBack, board.count(SortState.sentBack)),
      (SortState.waitingAdmin, board.count(SortState.waitingAdmin)),
      (
        SortState.inDelivery,
        board.count(SortState.inDelivery) + board.count(SortState.readyPickup)
      ),
      (SortState.delivered, board.count(SortState.delivered)),
      (SortState.notReceived, board.count(SortState.notReceived)),
    ];
    return PaperCard(
      key: const Key('sort-summary'),
      radius: heroRadius,
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
            atHub.isEmpty
                ? tr('Not received yet')
                : tr('Received at the Dhaka hub'),
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.muted)),
        const SizedBox(height: 2),
        Text(
            '${trn(orders, '{n} order', '{n} orders')} · ${tr('{kg} booked', {
                  'kg': kgText(kg)
                })}',
            style: const TextStyle(
                fontSize: 21, height: 1.3, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final (state, n) in counts)
            if (n > 0)
              StatusPill(
                  label: '${state.label} $n', tone: sortStateTone(state)),
        ]),
      ]),
    );
  }
}

class _CustomerRow extends StatelessWidget {
  const _CustomerRow({required this.group, required this.onTap});

  final SortGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = group;
    final partner = g.state.outForDelivery || g.state == SortState.delivered
        ? g.partner
        : null;
    final line = partner == null
        ? groupLine(g)
        : '${trn(g.orders.length, '{n} order', '{n} orders')} · ${tr(partner)}';
    return InkWell(
      key: Key('sort-customer-${g.customerCode}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          LayoutBuilder(builder: (context, box) {
            // On a narrow screen or with large text the pill goes under the
            // code, so the code always shows.
            final below = box.maxWidth < 300 ||
                MediaQuery.textScalerOf(context).scale(10) > 11.5;
            final pill = ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: SortStatePill(state: g.state));
            return Row(children: [
              CustomerMark(name: g.who),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(g.who,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15.5, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 1),
                      Text(line,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12.5, color: AppColors.muted)),
                      if (below) ...[const SizedBox(height: 6), pill],
                    ]),
              ),
              if (!below) ...[const SizedBox(width: 8), pill],
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: AppColors.faint),
            ]);
          }),
          if (g.state == SortState.sentBack && g.sentBackNote.isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 56),
              child: SortBanner(
                  tone: ChipTone.amber,
                  icon: Icons.undo_rounded,
                  title: '"${g.sentBackNote}"',
                  footnote: [
                    if (g.sentBackBy != null) g.sentBackBy!,
                    if (g.sentBackAt != null) whenText(g.sentBackAt!),
                  ].join(' · ')),
            ),
          ],
        ]),
      ),
    );
  }
}
