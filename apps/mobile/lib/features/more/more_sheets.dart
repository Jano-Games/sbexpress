import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/flow_parts.dart'
    show BigAmountField, SheetHeader, showFlowSheet;
import '../../widgets/more_parts.dart';
import '../../widgets/team_parts.dart' show plainNumber;
import '../../widgets/ui.dart';

/// Changes the CNY rate. True when it was saved.
Future<bool?> showRateSheet(BuildContext context, double current) =>
    showFlowSheet<bool>(context, (_) => _RateSheet(current: current));

/// Changes the weight alert. True when it was saved.
Future<bool?> showWeightAlertSheet(BuildContext context, double current) =>
    showFlowSheet<bool>(context, (_) => _WeightSheet(current: current));

class _RateSheet extends StatefulWidget {
  const _RateSheet({required this.current});
  final double current;

  @override
  State<_RateSheet> createState() => _RateSheetState();
}

class _RateSheetState extends State<_RateSheet> {
  late final _rate = TextEditingController(
      text: widget.current > 0 ? plainNumber(widget.current) : '');
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _rate.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final rate = double.tryParse(_rate.text.trim());
    if (rate == null || rate <= 0) {
      setState(() => _error =
          tr('Enter the real CNY rate. Blank or 0 will not be saved.'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.of(context).settings.saveRate(rate);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _SheetBody(
          title: tr('Exchange rate'),
          subtitle: tr('New transactions use this rate.'),
          children: [
            Text(tr('1 CNY = {amount}', {'amount': takaRate(widget.current)}),
                style: const TextStyle(
                    fontSize: 13, height: 1.4, color: AppColors.muted)),
            const SizedBox(height: 12),
            _Label(tr('BDT per CNY')),
            BigAmountField(
                key: const Key('rate-field'),
                controller: _rate,
                onChanged: (_) => setState(() => _error = null)),
            if (_error != null) ...[
              const SizedBox(height: 12),
              ErrorNote(message: _error!),
            ],
            const SizedBox(height: 16),
            AppButton(
                key: const Key('rate-save'),
                label: tr('Save rate'),
                icon: Icons.check_rounded,
                kind: AppButtonKind.current,
                busy: _busy,
                onPressed: _save),
          ]);
}

class _WeightSheet extends StatefulWidget {
  const _WeightSheet({required this.current});
  final double current;

  @override
  State<_WeightSheet> createState() => _WeightSheetState();
}

class _WeightSheetState extends State<_WeightSheet> {
  late final _kg = TextEditingController(text: plainNumber(widget.current));
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _kg.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final kg = double.tryParse(_kg.text.trim());
    if (kg == null || kg < 0) {
      setState(() => _error = tr('Enter the alert as a number, 0 or more.'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.of(context).settings.saveThreshold(kg);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _SheetBody(
          title: tr('Weight alert'),
          subtitle:
              tr('Warn when the weighed weight is this far from the booking.'),
          children: [
            _Label(tr('Weight alert in kg')),
            TextField(
                key: const Key('weight-field'),
                controller: _kg,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                ],
                onChanged: (_) => setState(() => _error = null),
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()]),
                decoration: const InputDecoration(
                    hintText: '0',
                    suffixText: 'kg',
                    suffixStyle: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted))),
            if (_error != null) ...[
              const SizedBox(height: 12),
              ErrorNote(message: _error!),
            ],
            const SizedBox(height: 16),
            AppButton(
                key: const Key('weight-save'),
                label: tr('Save alert'),
                icon: Icons.check_rounded,
                kind: AppButtonKind.current,
                busy: _busy,
                onPressed: _save),
          ]);
}

class _SheetBody extends StatelessWidget {
  const _SheetBody(
      {required this.title, required this.subtitle, required this.children});
  final String title, subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SheetHeader(title: title, subtitle: subtitle),
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children)),
      ]));
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 2),
      child: Text(text,
          style: const TextStyle(
              fontSize: 13, height: 1.35, fontWeight: FontWeight.w600)));
}
