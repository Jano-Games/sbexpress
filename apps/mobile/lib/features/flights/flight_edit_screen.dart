import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/flight.dart';
import '../../data/models/flight_route.dart';
import '../../data/models/hub_flight.dart' show FlightDay;
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/flight_parts.dart' show isClockTime;
import '../../widgets/flight_status_parts.dart' show checkedLabel;
import '../../widgets/quick_parts.dart' show plainKg;
import '../../widgets/round7_parts.dart' show NoteBox;
import '../../widgets/team_parts.dart' show FooterActions;
import '../../widgets/ui.dart';
import 'itinerary_parts.dart';

/// A flight's number, date, times, stops, space and status. Pops with the
/// saved flight: its reference changes with the number or the date.
class FlightEditScreen extends StatefulWidget {
  const FlightEditScreen({super.key, required this.flight});
  final FlightSummary flight;

  @override
  State<FlightEditScreen> createState() => _FlightEditScreenState();
}

class _FlightEditScreenState extends State<FlightEditScreen> {
  late final _itinerary = () {
    final flight = widget.flight;
    String clock(String time) {
      final trimmed = time.trim();
      if (!isClockTime(trimmed)) return '';
      return trimmed.length == 4 ? '0$trimmed' : trimmed.substring(0, 5);
    }

    final legs = flight.legs;
    return ItineraryController(
        number: flightNumberOf(flight.code),
        date: flight.date,
        depTime: clock(flight.depTime),
        arrTime: clock(flight.arrTime),
        stops: legs.length > 1 ? stopsOfLegs(legs) : '',
        baseLegs: legs);
  }();
  late final _space = TextEditingController(text: '${widget.flight.spaceKg}');
  late final _mobiles = TextEditingController(text: '${widget.flight.mobiles}');
  late final _laptops = TextEditingController(text: '${widget.flight.laptops}');
  late var _status = widget.flight.status;
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _itinerary.dispose();
    for (final field in [_space, _mobiles, _laptops]) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    _itinerary.showErrors = true;
    final problem = _itinerary.problem();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    final space = int.tryParse(_space.text.trim());
    final mobiles = int.tryParse(_mobiles.text.trim());
    final laptops = int.tryParse(_laptops.text.trim());
    if (space == null || space < 1) {
      setState(() => _error = tr('Enter the capacity in whole kg, 1 or more.'));
      return;
    }
    final booked = widget.flight.bookedKg;
    if (space + 0.000001 < booked) {
      setState(() => _error = tr(
          '{kg} kg is already booked on this flight. The capacity cannot be less than that.',
          {'kg': plainKg(booked)}));
      return;
    }
    if (mobiles == null || laptops == null) {
      setState(() => _error = tr('Enter 0 or more mobiles and laptops.'));
      return;
    }
    _itinerary.pauseLookups = true;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final code = await AppScope.of(context).flights.updateDetails(
          widget.flight.code,
          FlightEdit(
              date: _itinerary.date!,
              depTime: _itinerary.depTime.text.trim(),
              arrTime: _itinerary.arrTime.text.trim(),
              legs: _itinerary.legs(),
              spaceKg: space,
              mobiles: mobiles,
              laptops: laptops,
              status: _status == widget.flight.status ? null : _status));
      if (!mounted) return;
      Navigator.of(context).pop(code);
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      _itinerary.pauseLookups = false;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final flight = widget.flight;
    Widget number(String label, TextEditingController controller, Key key) =>
        TextField(
            key: key,
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: label));
    return WorkspaceScaffold(
        title: tr('Edit flight'),
        root: false,
        footer: FooterActions(
            error: _error,
            child: AppButton(
                key: const Key('flight-edit-save'),
                label: tr('Save changes'),
                icon: Icons.check_rounded,
                kind: AppButtonKind.current,
                busy: _busy,
                onPressed: _save)),
        children: [
          Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                  trn(flight.shipmentCount, '{flight} · {n} order',
                      '{flight} · {n} orders', {'flight': flight.displayCode}),
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.muted, height: 1.4))),
          ItineraryFields(controller: _itinerary),
          ListenableBuilder(
              listenable: _itinerary,
              builder: (context, _) {
                final moved =
                    _itinerary.date != null && _itinerary.date != flight.date;
                if (!moved) return const SizedBox.shrink();
                return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                        key: const Key('flight-edit-moved'),
                        tr('Moved from {date}. The orders and the flyer stay on this flight.',
                            {'date': _dayLabel(flight.date)}),
                        style: const TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: AppColors.muted)));
              }),
          const SizedBox(height: 20),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: number(
                    tr('Capacity kg'), _space, const Key('flight-edit-space'))),
            const SizedBox(width: 8),
            Expanded(
                child: number(
                    tr('Mobiles'), _mobiles, const Key('flight-edit-mobiles'))),
            const SizedBox(width: 8),
            Expanded(
                child: number(
                    tr('Laptops'), _laptops, const Key('flight-edit-laptops'))),
          ]),
          if (flight.bookedKg > 0) ...[
            const SizedBox(height: 6),
            Text(
                tr('{kg} kg is booked, so the capacity cannot go below that.',
                    {'kg': plainKg(flight.bookedKg)}),
                style: const TextStyle(
                    fontSize: 12, color: AppColors.muted, height: 1.4)),
          ],
          const SizedBox(height: 20),
          ListenableBuilder(
              listenable: _itinerary,
              builder: (context, _) => _StatusCard(
                  flight: flight,
                  status: _status,
                  dateMoved:
                      _itinerary.date != null && _itinerary.date != flight.date,
                  onChanged: (status) => setState(() => _status = status))),
          const SizedBox(height: 16),
          NoteBox(
              icon: Icons.info_outline_rounded,
              title: tr('The orders stay on this flight'),
              body: tr(
                  "If you change the number or the date, the flight's reference changes with it. Flyers and the ticket money are changed in Ticket and flyers.")),
        ]);
  }
}

/// "Fri 13 Nov".
String _dayLabel(String iso) {
  final day = FlightDay.parse(iso);
  return day == null ? iso : '${day.weekday} ${day.day} ${day.month}';
}

/// Upcoming, Departed or Landed, with what the airline last said.
class _StatusCard extends StatelessWidget {
  const _StatusCard(
      {required this.flight,
      required this.status,
      required this.dateMoved,
      required this.onChanged});
  final FlightSummary flight;
  final String status;
  final bool dateMoved;
  final ValueChanged<String> onChanged;

  String get _airline {
    final t = flight.tracking;
    if (t == null) {
      return tr(
          'Not checked with the airline yet. It is checked soon after take-off and after landing.');
    }
    if (dateMoved) {
      return t.noData
          ? tr(
              'Last airline check: no data for {date}. On the new date it is checked again after take-off and after landing.',
              {
                  'date': _dayLabel(flight.date)
                })
          : tr(
              'On the new date it is checked with the airline again after take-off and after landing.');
    }
    final time = checkedLabel(t.checkedAt);
    return switch (t.state) {
      'none' => tr('Last airline check {time}: no data for {date}.',
          {'time': time, 'date': _dayLabel(flight.date)}),
      'cancelled' => tr('Last airline check {time}: the airline cancelled it.',
          {'time': time}),
      'landed' => tr('Last airline check {time}: landed {arr}.',
          {'time': time, 'arr': t.landsAt ?? ''}),
      'on_the_way' => t.landsAt == null
          ? tr('Last airline check {time}: on the way.', {'time': time})
          : tr('Last airline check {time}: on the way, lands {arr}.',
              {'time': time, 'arr': t.landsAt}),
      _ => tr('Last airline check {time}: not left yet.', {'time': time}),
    };
  }

  @override
  Widget build(BuildContext context) {
    final fromAirline =
        flight.tracking != null || flight.statusSetBy == 'airline';
    final options = [
      ('upcoming', tr('Upcoming')),
      ('departed', tr('Departed')),
      ('completed', tr('Landed')),
    ];
    return PaperCard(
        key: const Key('flight-edit-status'),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(tr('Status'),
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, height: 1.3)),
          Text(
              fromAirline
                  ? tr(
                      'Set by itself from the airline. Change it here if it is wrong.')
                  : tr('Change it here if it is wrong.'),
              style: const TextStyle(
                  fontSize: 13, height: 1.45, color: AppColors.muted)),
          const SizedBox(height: 12),
          Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                  color: AppColors.neutralSoft,
                  borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                for (final (i, (value, label)) in options.indexed) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                      child: _Segment(
                          key: ValueKey('flight-status-$value'),
                          label: label,
                          selected: status == value,
                          onTap: () => onChanged(value))),
                ],
              ])),
          const SizedBox(height: 12),
          Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                  color: AppColors.paper,
                  borderRadius: BorderRadius.circular(12)),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(Icons.sync_rounded,
                        size: 18, color: AppColors.muted)),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(_airline,
                        key: const Key('flight-edit-airline'),
                        style: const TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: AppColors.inkSoft))),
              ])),
          const SizedBox(height: 10),
          Text(tr('Departed or Landed moves the orders ready for shipment to In transit. The hub receives them after customs.'),
              style: const TextStyle(
                  fontSize: 12, height: 1.45, color: AppColors.muted)),
        ]));
  }
}

class _Segment extends StatelessWidget {
  const _Segment(
      {super.key,
      required this.label,
      required this.selected,
      required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: Material(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onTap,
              child: SizedBox(
                  height: 44,
                  child: Center(
                      child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: selected
                                      ? Colors.white
                                      : AppColors.inkSoft))))))));
}
