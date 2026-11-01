import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/flight.dart';
import '../../data/models/workspace.dart';
import '../../data/money_payload.dart';
import '../../data/rates.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/flow_parts.dart';
import '../../widgets/quick_parts.dart' show PillToggle, wholeMoney;
import '../../widgets/rate_parts.dart';
import '../../widgets/round7_parts.dart';
import '../../widgets/ui.dart';

/// Sets a flight's own rates for new orders, or sends it back to the
/// default. Returns how many orders moved along, or null when closed.
Future<int?> showFlightRatesSheet(BuildContext context,
        {required FlightDetail detail, required SettingsSnapshot? defaults}) =>
    showFlowSheet<int>(
        context, (_) => FlightRatesSheet(detail: detail, defaults: defaults));

class FlightRatesSheet extends StatefulWidget {
  const FlightRatesSheet(
      {super.key, required this.detail, required this.defaults});

  final FlightDetail detail;

  /// The default rates; null when they did not load.
  final SettingsSnapshot? defaults;

  @override
  State<FlightRatesSheet> createState() => _FlightRatesSheetState();
}

class _FlightRatesSheetState extends State<FlightRatesSheet> {
  late var _own = widget.detail.summary.ownRates != null;
  final _kg = TextEditingController();
  var _currency = 'BDT';
  final _pieces = <String, TextEditingController>{};
  var _apply = true;
  var _busy = false;
  String? _error;

  FlightSummary get _flight => widget.detail.summary;

  @override
  void initState() {
    super.initState();
    final own = _flight.ownRates;
    final defaults = widget.defaults;
    _kg.text = rateText(own?.kgRate ?? defaults?.kgRate);
    _currency = own?.currency ?? defaults?.kgRateCurrency ?? 'BDT';
    final names = <String>[];
    void add(String name) {
      if (!names.any((n) => n.toLowerCase() == name.toLowerCase())) {
        names.add(name);
      }
    }

    for (final name in defaults?.pcsRates.keys ?? const <String>[]) {
      add(name);
    }
    for (final name in own?.pcsRates.keys ?? const <String>[]) {
      add(name);
    }
    for (final name in names) {
      final price = pieceRate(own?.pcsRates ?? const {}, name) ??
          pieceRate(defaults?.pcsRates ?? const {}, name);
      _pieces[name] = TextEditingController(text: rateText(price));
    }
  }

  @override
  void dispose() {
    _kg.dispose();
    for (final field in _pieces.values) {
      field.dispose();
    }
    super.dispose();
  }

  String get _defaultLine {
    final kg = widget.defaults?.kgRate;
    if (kg == null) return tr('No default rate per kg yet');
    return tr('Default is {rate} per kg',
        {'rate': wholeMoney(kg, widget.defaults!.kgRateCurrency)});
  }

  Future<void> _save() async {
    double? kg;
    final prices = <String, double>{};
    if (_own) {
      kg = parseMoney(_kg.text);
      if (kg == null || kg <= 0) {
        setState(() => _error = tr("Enter this flight's rate per kg."));
        return;
      }
      for (final entry in _pieces.entries) {
        final text = entry.value.text.trim();
        if (text.isEmpty) continue;
        final price = parseMoney(text);
        if (price == null || price < 0) {
          setState(() => _error = tr(
              'Enter the price for {name} as a number.', {'name': entry.key}));
          return;
        }
        prices[entry.key] = price;
      }
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updated = await AppScope.of(context).flights.saveRates(
          widget.detail.summary.code,
          own: _own,
          kgRate: kg,
          currency: _currency,
          pcsRates: prices,
          applyToOrders: _apply && widget.detail.rateFollowers > 0);
      if (mounted) Navigator.of(context).pop(updated);
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.status == 404
          ? tr('The server needs an update before flight rates can be saved.')
          : error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final followers = widget.detail.rateFollowers;
    return SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 18),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SheetHeader(
              title: tr('Rates for {flight}', {'flight': _flight.displayCode}),
              subtitle: _defaultLine),
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ModeSwitch(
                        own: _own,
                        onChanged: (own) => setState(() {
                              _own = own;
                              _error = null;
                            })),
                    const SizedBox(height: 16),
                    if (_own) ...[
                      Row(children: [
                        Expanded(child: SheetLabel(tr('Rate per kg'))),
                        PillToggle(
                            key: const Key('flight-rates-currency'),
                            options: const ['BDT', 'CNY'],
                            selected: _currency,
                            onChanged: (value) =>
                                setState(() => _currency = value)),
                      ]),
                      const SizedBox(height: 8),
                      RateField(
                          key: const Key('flight-rates-kg'),
                          controller: _kg,
                          currency: _currency,
                          unit: tr('per kg'),
                          large: true,
                          onChanged: (_) => setState(() => _error = null)),
                      if (_pieces.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        SheetLabel(tr('Piece prices')),
                        for (final entry in _pieces.entries)
                          PiecePriceRow(
                              name: entry.key,
                              controller: entry.value,
                              onChanged: (_) => setState(() => _error = null)),
                      ],
                    ] else
                      Text(tr('New orders on this flight use the rates from Rates and prices in More.'),
                          style: const TextStyle(
                              fontSize: 13,
                              height: 1.45,
                              color: AppColors.muted)),
                    if (followers > 0) ...[
                      const SizedBox(height: 16),
                      _ApplyBox(
                          count: followers,
                          value: _apply,
                          onChanged: (value) => setState(() => _apply = value)),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      ErrorNote(message: _error!),
                    ],
                    const SizedBox(height: 16),
                    AppButton(
                        key: const Key('flight-rates-save'),
                        label: tr('Save rates'),
                        icon: Icons.check_rounded,
                        kind: AppButtonKind.current,
                        busy: _busy,
                        onPressed: _save),
                  ])),
        ]));
  }
}

/// "Use the default" or "Own rates".
class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.own, required this.onChanged});
  final bool own;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget option(bool value, String label, Key key) {
      final selected = own == value;
      return Expanded(
          child: Semantics(
              button: true,
              selected: selected,
              inMutuallyExclusiveGroup: true,
              child: Material(
                  color: selected ? AppColors.card : Colors.transparent,
                  elevation: selected ? 1 : 0,
                  shadowColor: const Color(0x33101828),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                      key: key,
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => onChanged(value),
                      child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 44),
                          child: Center(
                              child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(label,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 14,
                                          height: 1.3,
                                          fontWeight: selected
                                              ? FontWeight.w700
                                              : FontWeight.w600,
                                          color: selected
                                              ? AppColors.ink
                                              : AppColors.muted)))))))));
    }

    return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            color: AppColors.lineSoft, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          option(
              false, tr('Use the default'), const Key('flight-rates-default')),
          const SizedBox(width: 4),
          option(true, tr('Own rates'), const Key('flight-rates-own')),
        ]));
  }
}

/// Tick to carry the flight's orders along to the new rates.
class _ApplyBox extends StatelessWidget {
  const _ApplyBox(
      {required this.count, required this.value, required this.onChanged});
  final int count;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Material(
      color: AppColors.card,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.field)),
      child: InkWell(
          key: const Key('flight-rates-apply'),
          borderRadius: BorderRadius.circular(14),
          onTap: () => onChanged(!value),
          child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 14, 10),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                IgnorePointer(child: Checkbox(value: value, onChanged: (_) {})),
                const SizedBox(width: 4),
                Expanded(
                    child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  trn(
                                      count,
                                      'Also change the {n} order already on this flight',
                                      'Also change the {n} orders already on this flight'),
                                  style: const TextStyle(
                                      fontSize: 14,
                                      height: 1.35,
                                      fontWeight: FontWeight.w600)),
                              Text(tr('Unpaid orders still on the old rates move to the new ones. Paid orders and orders with another rate stay as they are. Their bills update by themselves.'),
                                  style: const TextStyle(
                                      fontSize: 12,
                                      height: 1.4,
                                      color: AppColors.muted)),
                            ]))),
              ]))));
}
