import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/flight.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/flight_parts.dart' show CategoryChip;
import '../../widgets/flow_parts.dart' show SheetHeader, showFlowSheet;
import '../../widgets/quick_parts.dart' show plainKg;
import '../../widgets/ui.dart';

/// The capacity new flights and tickets start with. True once saved.
Future<bool?> showDefaultCapacitySheet(BuildContext context, int current) =>
    showFlowSheet<bool>(
        context,
        (_) => CapacitySheet(
            title: tr('Flight capacity'),
            subtitle: tr(
                'New flights and tickets start with this. Each flight can still have its own.'),
            current: current,
            save: (context, kg) async {
              final saved =
                  await AppScope.of(context).settings.saveDefaultSpace(kg);
              return saved.defaultSpaceKg == null
                  ? tr(
                      'The server needs an update to keep the default capacity.')
                  : null;
            }));

/// One flight's capacity, never below what is already booked on it.
/// True once saved.
Future<bool?> showFlightCapacitySheet(BuildContext context,
        {required FlightSummary flight}) =>
    showFlowSheet<bool>(
        context,
        (_) => CapacitySheet(
            title: tr('Capacity for {flight}', {'flight': flight.displayCode}),
            subtitle:
                tr('{kg} kg booked so far', {'kg': plainKg(flight.bookedKg)}),
            current: flight.spaceKg,
            bookedKg: flight.bookedKg,
            save: (context, kg) async {
              await AppScope.of(context)
                  .flights
                  .updateCapacity(flight.code, kg);
              return null;
            }));

class CapacitySheet extends StatefulWidget {
  const CapacitySheet(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.current,
      required this.save,
      this.bookedKg});

  final String title, subtitle;
  final int current;

  /// Kg already booked on the flight; null for the default.
  final double? bookedKg;

  /// Saves [kg]; returns an error to show, or null when done.
  final Future<String?> Function(BuildContext context, int kg) save;

  @override
  State<CapacitySheet> createState() => _CapacitySheetState();
}

class _CapacitySheetState extends State<CapacitySheet> {
  late final _kg = TextEditingController(text: '${widget.current}');
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _kg.dispose();
    super.dispose();
  }

  int? get _value => int.tryParse(_kg.text.trim());

  void _pick(int kg) => setState(() {
        _kg.text = '$kg';
        _error = null;
      });

  Future<void> _save() async {
    final kg = _value;
    if (kg == null || kg < 1) {
      setState(() => _error = tr('Enter the capacity in whole kg, 1 or more.'));
      return;
    }
    final booked = widget.bookedKg ?? 0;
    if (kg + 0.000001 < booked) {
      setState(() => _error = tr(
          '{kg} kg is already booked on this flight. The capacity cannot be less than that.',
          {'kg': plainKg(booked)}));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final error = await widget.save(context, kg);
      if (!mounted) return;
      if (error != null) {
        setState(() => _error = error);
        return;
      }
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = _value;
    final booked = widget.bookedKg;
    final left = booked == null || value == null ? null : value - booked;
    return SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 18),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SheetHeader(title: widget.title, subtitle: widget.subtitle),
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                        key: const Key('capacity-field'),
                        controller: _kg,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        onChanged: (_) => setState(() => _error = null),
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            fontFeatures: [FontFeature.tabularFigures()]),
                        decoration: InputDecoration(
                            labelText: tr('Capacity kg'),
                            hintText: '44',
                            suffixText: 'kg',
                            suffixStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.muted))),
                    const SizedBox(height: 10),
                    Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(tr('Usually 44 or 52'),
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.muted)),
                          for (final kg in const [44, 52])
                            CategoryChip(
                                key: ValueKey('capacity-$kg'),
                                label: '$kg kg',
                                selected: value == kg,
                                onTap: () => _pick(kg)),
                        ]),
                    if (left != null) ...[
                      const SizedBox(height: 12),
                      Text(
                          key: const Key('capacity-left'),
                          left < 0
                              ? tr('{kg} kg over', {'kg': plainKg(-left)})
                              : tr('{kg} kg free', {'kg': plainKg(left)}),
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: left < 0
                                  ? AppColors.danger
                                  : AppColors.inkSoft)),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      ErrorNote(message: _error!),
                    ],
                    const SizedBox(height: 16),
                    AppButton(
                        key: const Key('capacity-save'),
                        label: tr('Save capacity'),
                        icon: Icons.check_rounded,
                        kind: AppButtonKind.current,
                        busy: _busy,
                        onPressed: _save),
                  ])),
        ]));
  }
}
