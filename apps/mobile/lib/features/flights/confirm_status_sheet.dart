import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/flight.dart';
import '../../data/models/flight_route.dart';
import '../../data/models/hub_flight.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/flow_parts.dart' show SheetHeader, showFlowSheet;
import '../../widgets/ui.dart';
import 'hub_flights_screen.dart' show banglaPlace;

/// What the person said happened to the flight.
sealed class ConfirmOutcome {
  const ConfirmOutcome();
}

/// The status was saved; [saved] names the orders that moved.
class StatusConfirmed extends ConfirmOutcome {
  const StatusConfirmed(this.status, this.saved);
  final String status;
  final FlightSaved saved;
}

/// It flies on another day: the caller opens Edit flight.
class FliesAnotherDay extends ConfirmOutcome {
  const FliesAnotherDay();
}

/// Asks what happened to a flight whose date is over (or that the airline
/// cancelled) and saves it. [readyCount] is how many orders are ready for
/// shipment, when the caller knows.
Future<ConfirmOutcome?> showConfirmStatusSheet(BuildContext context,
        {required FlightSummary flight, int? readyCount}) =>
    showFlowSheet<ConfirmOutcome>(context,
        (_) => ConfirmStatusSheet(flight: flight, readyCount: readyCount));

/// The snackbar after a confirmed status.
String confirmedMessage(String flight, StatusConfirmed outcome) {
  final first = outcome.status == 'completed'
      ? tr('{code} has landed.', {'code': flight})
      : tr('{code} is on the way.', {'code': flight});
  final moved = outcome.saved.moved.length;
  if (moved == 0) return first;
  return '$first ${trn(moved, '{n} order moved to In transit.', '{n} orders moved to In transit.')}';
}

class ConfirmStatusSheet extends StatefulWidget {
  const ConfirmStatusSheet({super.key, required this.flight, this.readyCount});
  final FlightSummary flight;
  final int? readyCount;

  @override
  State<ConfirmStatusSheet> createState() => _ConfirmStatusSheetState();
}

class _ConfirmStatusSheetState extends State<ConfirmStatusSheet> {
  var _choice = 'departed';
  var _busy = false;
  String? _error;

  String get _flewBody {
    final n = widget.readyCount;
    if (n == null) {
      return tr(
          'Status becomes Departed. Orders ready for shipment move to In transit.');
    }
    if (n == 0) return tr('Status becomes Departed.');
    return trn(
        n,
        'Status becomes Departed. The {n} order ready for shipment moves to In transit.',
        'Status becomes Departed. The {n} orders ready for shipment move to In transit.');
  }

  String get _landedBody {
    final n = widget.readyCount;
    if (n == null || n == 0) {
      return tr(
          'Status becomes Landed. The hub receives the orders after customs.');
    }
    return trn(
        n,
        'Status becomes Landed. The {n} order ready for shipment moves to In transit; the hub receives it after customs.',
        'Status becomes Landed. The {n} orders ready for shipment move to In transit; the hub receives them after customs.');
  }

  Future<void> _save() async {
    if (_choice == 'another_day') {
      Navigator.of(context).pop(const FliesAnotherDay());
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await AppScope.of(context)
          .flights
          .setStatus(widget.flight.code, _choice);
      if (!mounted) return;
      Navigator.of(context).pop(StatusConfirmed(_choice, saved));
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final flight = widget.flight;
    final day = FlightDay.parse(flight.date);
    final from = banglaPlace(flight.from, fallback: tr('China'));
    final planned = [
      if (day != null) '${day.weekday} ${day.day} ${day.month}',
      if (RegExp(r'^\d{1,2}:\d{2}').hasMatch(flight.depTime.trim()))
        tr('{time} from {place}', {'time': flight.depTime, 'place': from}),
    ].join(' · ');
    return SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 18),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SheetHeader(
              title:
                  tr('What happened to {code}?', {'code': flight.displayCode}),
              subtitle: planned.isEmpty
                  ? null
                  : tr('Planned {when}', {'when': planned})),
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Choice(
                        key: const Key('confirm-departed'),
                        selected: _choice == 'departed',
                        icon: Icons.flight_takeoff_rounded,
                        title: tr('It flew, on the way'),
                        body: _flewBody,
                        onTap: () => setState(() => _choice = 'departed')),
                    const SizedBox(height: 10),
                    _Choice(
                        key: const Key('confirm-completed'),
                        selected: _choice == 'completed',
                        icon: Icons.flight_land_rounded,
                        title: tr('It landed'),
                        body: _landedBody,
                        onTap: () => setState(() => _choice = 'completed')),
                    const SizedBox(height: 10),
                    _Choice(
                        key: const Key('confirm-another-day'),
                        selected: _choice == 'another_day',
                        icon: Icons.event_outlined,
                        title: tr('It flies on another day'),
                        body: tr(
                            'Opens Edit flight to change the date. Nothing else changes.'),
                        onTap: () => setState(() => _choice = 'another_day')),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      ErrorNote(message: _error!),
                    ],
                    const SizedBox(height: 16),
                    AppButton(
                        key: const Key('confirm-save'),
                        label: _choice == 'another_day'
                            ? tr('Change date')
                            : tr('Save'),
                        icon: _choice == 'another_day'
                            ? Icons.event_outlined
                            : Icons.check_rounded,
                        kind: AppButtonKind.current,
                        busy: _busy,
                        onPressed: _save),
                    const SizedBox(height: 10),
                    Text(tr('Your name goes on this change. If the airline sends an update later, it can only move the flight forward.'),
                        style: const TextStyle(
                            fontSize: 12,
                            height: 1.45,
                            color: AppColors.muted)),
                  ])),
        ]));
  }
}

class _Choice extends StatelessWidget {
  const _Choice(
      {super.key,
      required this.selected,
      required this.icon,
      required this.title,
      required this.body,
      required this.onTap});
  final bool selected;
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: Material(
          color: selected ? AppColors.primarySoft : AppColors.card,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                  color: selected ? AppColors.primary : AppColors.field,
                  width: selected ? 2 : 1)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
              onTap: onTap,
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                                color: AppColors.card,
                                border: Border.all(color: AppColors.line),
                                borderRadius: BorderRadius.circular(12)),
                            child:
                                Icon(icon, size: 20, color: AppColors.inkSoft)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(title,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      height: 1.35,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text(body,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      height: 1.45,
                                      color: AppColors.muted)),
                            ])),
                        const SizedBox(width: 8),
                        Icon(
                            selected
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_off_rounded,
                            size: 22,
                            color:
                                selected ? AppColors.primary : AppColors.faint),
                      ])))));
}
