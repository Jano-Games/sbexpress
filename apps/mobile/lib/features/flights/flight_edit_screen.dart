import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/flight.dart';
import '../../data/models/flight_route.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/flight_parts.dart' show isClockTime;
import '../../widgets/quick_parts.dart' show plainKg;
import '../../widgets/round7_parts.dart' show NoteBox;
import '../../widgets/team_parts.dart' show FooterActions;
import '../../widgets/ui.dart';
import 'itinerary_parts.dart';

/// A flight's number, date, times, stops and space. Pops with the flight's
/// reference once saved; it changes with the number or the date.
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
              laptops: laptops));
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
          const SizedBox(height: 16),
          NoteBox(
              icon: Icons.info_outline_rounded,
              title: tr('The orders stay on this flight'),
              body: tr(
                  "If you change the number or the date, the flight's reference changes with it. Flyers and the ticket money are changed in Ticket and flyers.")),
        ]);
  }
}
