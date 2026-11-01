import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/shipment.dart';
import '../../data/models/workspace.dart';
import '../../data/money_payload.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/flight_parts.dart' show CategoryChip;
import '../../widgets/flow_parts.dart';
import '../../widgets/quick_parts.dart' show PillToggle, plainKg, wholeMoney;
import '../../widgets/rate_parts.dart';
import '../../widgets/round7_parts.dart';
import '../../widgets/ui.dart';

/// Changes an order's booked kg, rate per kg and pieces. True once saved;
/// the server works out the new charge and the bill follows it.
Future<bool?> showOrderChargeSheet(BuildContext context,
        {required AdminShipmentDetail detail}) =>
    showFlowSheet<bool>(context, (_) => OrderChargeSheet(detail: detail));

class OrderChargeSheet extends StatefulWidget {
  const OrderChargeSheet({super.key, required this.detail});

  final AdminShipmentDetail detail;

  @override
  State<OrderChargeSheet> createState() => _OrderChargeSheetState();
}

class _Piece {
  _Piece(this.line)
      : count = line.count,
        price = TextEditingController(text: rateText(line.rate));

  final AdminDeviceLine line;
  int count;
  final TextEditingController price;

  double get priceValue => double.tryParse(price.text.trim()) ?? 0;

  /// One unit per piece: the ones there are, then blank ones, or the last
  /// ones dropped.
  Map<String, Object?> toJson() => {
        'category': line.category,
        'count': count,
        'rate': roundMoney(priceValue),
        'currency': line.currency,
        'units': [
          for (var i = 0; i < count; i++)
            if (i < line.units.length)
              {
                'model': line.units[i].model,
                'serial': line.units[i].serial,
                if (line.units[i].hasPhoto)
                  'serialPhotoRef': line.units[i].serialPhotoRef,
              }
            else
              {'model': '', 'serial': ''},
        ],
      };

  bool get changed => count != line.count || priceValue != line.rate;
}

class _OrderChargeSheetState extends State<OrderChargeSheet> {
  late final _kg = TextEditingController(text: plainKg(widget.detail.bookedKg));
  late final _rate =
      TextEditingController(text: rateText(widget.detail.chargeRate));
  late var _currency = widget.detail.chargeCurrency == 'CNY' ? 'CNY' : 'BDT';
  late final _pieces = [
    for (final line in widget.detail.devices)
      if (line.count > 0) _Piece(line)
  ];

  /// Quick rates: the default and the flight's own, when they load.
  ({double rate, String currency})? _default;
  ({String flight, double rate, String currency})? _flight;
  var _busy = false;
  String? _error;

  AdminShipmentDetail get _detail => widget.detail;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadQuickRates());
  }

  @override
  void dispose() {
    _kg.dispose();
    _rate.dispose();
    for (final piece in _pieces) {
      piece.price.dispose();
    }
    super.dispose();
  }

  /// Best effort: without them the sheet still works, just without chips.
  Future<void> _loadQuickRates() async {
    final scope = AppScope.of(context);
    SettingsSnapshot? settings;
    try {
      settings = await scope.settings.current();
    } catch (_) {
      return;
    }
    final kg = settings.kgRate;
    if (mounted && kg != null) {
      setState(() => _default = (rate: kg, currency: settings!.kgRateCurrency));
    }
    final code = _detail.flightCode;
    if (code == null) return;
    try {
      final flight = (await scope.flights.detail(code)).summary;
      final own = flight.ownRates;
      if (!mounted || own == null) return;
      setState(() => _flight = (
            flight: flight.displayCode,
            rate: own.kgRate,
            currency: own.currency
          ));
    } catch (_) {
      // No flight chip.
    }
  }

  double? get _kgValue => double.tryParse(_kg.text.trim());
  double? get _rateValue => double.tryParse(_rate.text.trim());

  /// The kg the charge is worked out on: weighed once the hub weighs it.
  double get _chargeKg => _detail.weighedKg ?? _kgValue ?? 0;

  /// The new charge when everything is in one currency; null otherwise.
  ({double amount, String currency})? get _total {
    final currencies = {
      if (_chargeKg > 0) _currency,
      for (final piece in _pieces) piece.line.currency,
    };
    if (currencies.length > 1) return null;
    final amount = _chargeKg * (_rateValue ?? 0) +
        _pieces.fold(0.0, (sum, piece) => sum + piece.count * piece.priceValue);
    return (
      amount: roundMoney(amount),
      currency: currencies.isEmpty ? 'BDT' : currencies.single
    );
  }

  void _quickRate(double rate, String currency) => setState(() {
        _rate.text = rateText(rate);
        _currency = currency;
        _error = null;
      });

  Future<void> _save() async {
    final kg = _kgValue;
    final rate = _rateValue;
    if (kg == null || kg < 0) {
      setState(() => _error = tr('Enter the booked kg as a number.'));
      return;
    }
    if (rate == null || rate < 0) {
      setState(() => _error = tr('Enter the rate per kg as a number.'));
      return;
    }
    for (final piece in _pieces) {
      final price = double.tryParse(piece.price.text.trim());
      if (price == null || price < 0) {
        setState(() => _error = tr('Enter the price for {name} as a number.',
            {'name': piece.line.category}));
        return;
      }
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.of(context).shipments.updateCharge(_detail.code,
          bookedKg: kg,
          chargeRate: roundMoney(rate),
          currency: _currency,
          pcsItems: _pieces.any((piece) => piece.changed)
              ? [for (final piece in _pieces) piece.toJson()]
              : null);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _total;
    final weighed = _detail.weighedKg;
    final quick = <Widget>[
      if (_default case final value?)
        CategoryChip(
            key: const Key('order-rate-default'),
            label: tr('Default {rate}',
                {'rate': wholeMoney(value.rate, value.currency)}),
            selected: _rateValue == value.rate && _currency == value.currency,
            onTap: () => _quickRate(value.rate, value.currency)),
      if (_flight case final value?)
        CategoryChip(
            key: const Key('order-rate-flight'),
            label: '${value.flight} ${wholeMoney(value.rate, value.currency)}',
            selected: _rateValue == value.rate && _currency == value.currency,
            onTap: () => _quickRate(value.rate, value.currency)),
    ];
    return SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 18),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SheetHeader(
              title: tr('Weight and rate'),
              subtitle: tr('{code} · now {amount}', {
                'code': _detail.code,
                'amount': wholeMoney(_detail.charge, 'BDT')
              })),
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Expanded(child: SheetLabel(tr('Booked kg'))),
                      PillToggle(
                          key: const Key('order-rate-currency'),
                          options: const ['BDT', 'CNY'],
                          selected: _currency,
                          onChanged: (value) => setState(() {
                                _currency = value;
                                _error = null;
                              })),
                    ]),
                    const SizedBox(height: 8),
                    _Pair(
                        first: TextField(
                            key: const Key('order-kg'),
                            controller: _kg,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.]'))
                            ],
                            onChanged: (_) => setState(() => _error = null),
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700),
                            decoration: InputDecoration(
                                hintText: '0',
                                labelText: tr('Booked kg'),
                                suffixText: 'kg')),
                        second: Semantics(
                            label: tr('Rate per kg'),
                            child: RateField(
                                key: const Key('order-rate'),
                                controller: _rate,
                                currency: _currency,
                                unit: tr('per kg'),
                                onChanged: (_) =>
                                    setState(() => _error = null)))),
                    if (quick.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(tr('Quick rate'),
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.muted)),
                            ...quick,
                          ]),
                    ],
                    if (_pieces.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      SheetLabel(tr('Pieces')),
                      for (final piece in _pieces)
                        PiecePriceRow(
                            name: piece.line.category,
                            controller: piece.price,
                            onChanged: (_) => setState(() => _error = null),
                            leading: CountStepper(
                                name: piece.line.category,
                                count: piece.count,
                                onChanged: (count) =>
                                    setState(() => piece.count = count))),
                    ],
                    const SizedBox(height: 16),
                    _NewCharge(
                        basis: [
                          if (_chargeKg > 0 || _pieces.isEmpty)
                            '${plainKg(_chargeKg)} kg × ${wholeMoney(_rateValue ?? 0, _currency)}',
                          for (final piece in _pieces)
                            '${piece.count} ${piece.line.category} × ${wholeMoney(piece.priceValue, piece.line.currency)}',
                        ].join(' + '),
                        was: tr('Was {amount}',
                            {'amount': wholeMoney(_detail.charge, 'BDT')}),
                        total: total == null
                            ? null
                            : wholeMoney(total.amount, total.currency)),
                    const SizedBox(height: 8),
                    Text(
                        weighed == null
                            ? tr(
                                'The bill and the customer link update by themselves. After the hub weighs it, the charge uses the weighed kg.')
                            : tr(
                                'Weighed at the hub: {kg} kg. The charge uses the weighed kg; the bill updates by itself.',
                                {
                                    'kg': plainKg(weighed)
                                  }),
                        style: const TextStyle(
                            fontSize: 12, height: 1.4, color: AppColors.muted)),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      ErrorNote(message: _error!),
                    ],
                    const SizedBox(height: 16),
                    AppButton(
                        key: const Key('order-charge-save'),
                        label: total == null
                            ? tr('Save')
                            : tr('Save · {amount}', {
                                'amount':
                                    wholeMoney(total.amount, total.currency)
                              }),
                        icon: Icons.check_rounded,
                        kind: AppButtonKind.current,
                        busy: _busy,
                        onPressed: _save),
                  ])),
        ]));
  }
}

/// Two fields side by side, or one under the other on a narrow phone so a
/// four-digit rate still fits beside its unit.
class _Pair extends StatelessWidget {
  const _Pair({required this.first, required this.second});
  final Widget first, second;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
      builder: (context, box) => box.maxWidth < 340
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [first, const SizedBox(height: 10), second])
          : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: first),
              const SizedBox(width: 10),
              Expanded(child: second),
            ]));
}

/// Dark strip with how the new charge is made up and the total.
class _NewCharge extends StatelessWidget {
  const _NewCharge({required this.basis, required this.was, this.total});
  final String basis, was;
  final String? total;

  @override
  Widget build(BuildContext context) => Semantics(
      liveRegion: true,
      child: Container(
          key: const Key('order-charge-preview'),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
              color: AppColors.navy, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(basis,
                      style: const TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color: Color(0xFFB8C4D9))),
                  Text(was,
                      style: const TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color: Color(0xFFB8C4D9))),
                ])),
            if (total != null) ...[
              const SizedBox(width: 10),
              Text(total!,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontFeatures: [FontFeature.tabularFigures()])),
            ],
          ])));
}
