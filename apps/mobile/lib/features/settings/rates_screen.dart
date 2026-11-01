import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/workspace.dart';
import '../../data/money_payload.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/quick_parts.dart' show PillToggle;
import '../../widgets/rate_parts.dart';
import '../../widgets/round7_parts.dart';
import '../../widgets/team_parts.dart' show DashedOutline;
import '../../widgets/ui.dart';

/// Device categories that are charged per piece rather than by weight.
final devicePattern = RegExp(
    'mobile|phone|laptop|drone|tablet|ipad|watch|camera',
    caseSensitive: false);

/// The default rate per kg and piece prices every new order starts with.
/// Set once here; a flight can have its own, and each order can change them.
class RatesScreen extends StatefulWidget {
  const RatesScreen({super.key});

  @override
  State<RatesScreen> createState() => _RatesScreenState();
}

class _RatesScreenState extends State<RatesScreen> {
  final _kg = TextEditingController();
  var _currency = 'BDT';

  /// Category name → price field, in the order shown.
  final _pieces = <String, TextEditingController>{};
  List<String> _categories = const [];
  final _newName = TextEditingController();
  var _adding = false;
  var _loading = true;
  var _busy = false;
  String? _error;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _kg.dispose();
    _newName.dispose();
    for (final field in _pieces.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final scope = AppScope.of(context);
      final settings = await scope.settings.current();
      final categories = await scope.settings.categories();
      if (!mounted) return;
      setState(() => _fill(settings, categories));
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _loadError = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _fill(SettingsSnapshot settings, List<String> categories) {
    _categories = categories;
    _kg.text = rateText(settings.kgRate);
    _currency = settings.kgRateCurrency;
    for (final field in _pieces.values) {
      field.dispose();
    }
    _pieces
      ..clear()
      ..addAll({
        for (final entry in settings.pcsRates.entries)
          entry.key: TextEditingController(text: rateText(entry.value)),
      });
  }

  /// Device categories without a price yet, offered as quick chips.
  List<String> get _unpriced {
    final priced = {for (final name in _pieces.keys) name.toLowerCase()};
    return [
      for (final name in _categories)
        if (devicePattern.hasMatch(name) &&
            !priced.contains(name.toLowerCase()))
          name
    ];
  }

  void _addPiece(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return;
    final exists =
        _pieces.keys.any((key) => key.toLowerCase() == clean.toLowerCase());
    setState(() {
      if (!exists) _pieces[clean] = TextEditingController();
      _adding = false;
      _newName.clear();
      _error = null;
    });
  }

  void _removePiece(String name) => setState(() {
        _pieces.remove(name)?.dispose();
        _error = null;
      });

  Future<void> _save() async {
    final kgText = _kg.text.trim();
    final kg = kgText.isEmpty ? 0.0 : parseMoney(kgText);
    if (kg == null || kg < 0) {
      setState(() => _error = tr('Enter the rate per kg as a number.'));
      return;
    }
    final prices = <String, double>{};
    for (final entry in _pieces.entries) {
      final text = entry.value.text.trim();
      if (text.isEmpty) continue;
      final price = parseMoney(text);
      if (price == null || price < 0) {
        setState(() => _error =
            tr('Enter the price for {name} as a number.', {'name': entry.key}));
        return;
      }
      prices[entry.key] = price;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await AppScope.of(context)
          .settings
          .saveRates(kgRate: kg, currency: _currency, pcsRates: prices);
      if (!mounted) return;
      if (!saved.ratesKnown) {
        setState(() => _error = tr(
            'Piece prices are saved. The server needs an update to keep the rate per kg.'));
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('Rates saved'))));
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
    final unpriced = _unpriced;
    return WorkspaceScaffold(
        title: tr('Rates and prices'),
        subtitle: tr('New orders start with these'),
        footer: _loading || _loadError != null
            ? null
            : AppButton(
                key: const Key('rates-save'),
                label: tr('Save rates'),
                icon: Icons.check_rounded,
                kind: AppButtonKind.current,
                busy: _busy,
                onPressed: _save),
        children: [
          if (_loading)
            const LinearProgressIndicator()
          else if (_loadError != null)
            ErrorNote(message: _loadError!, onRetry: _load)
          else ...[
            PaperCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  CardHead(
                      title: tr('Rate per kg'),
                      subtitle: tr('For the weighed cargo'),
                      trailing: PillToggle(
                          key: const Key('rates-currency'),
                          options: const ['BDT', 'CNY'],
                          selected: _currency,
                          onChanged: (value) =>
                              setState(() => _currency = value))),
                  const SizedBox(height: 12),
                  RateField(
                      key: const Key('rates-kg'),
                      controller: _kg,
                      currency: _currency,
                      unit: tr('per kg'),
                      large: true,
                      onChanged: (_) => setState(() => _error = null)),
                ])),
            const SizedBox(height: 12),
            PaperCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  CardHead(
                      title: tr('Piece prices'),
                      subtitle:
                          tr('Devices are charged per piece, not by weight')),
                  const SizedBox(height: 6),
                  if (_pieces.isEmpty)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(tr('No piece prices yet.'),
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.muted))),
                  for (final entry in _pieces.entries)
                    PiecePriceRow(
                        name: entry.key,
                        controller: entry.value,
                        onChanged: (_) => setState(() => _error = null),
                        onRemove: () => _removePiece(entry.key)),
                  const SizedBox(height: 10),
                  Text(tr('Add a price for'),
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.muted)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final name in unpriced)
                      _AddChip(
                          key: ValueKey('rates-add-$name'),
                          label: name,
                          onTap: () => _addPiece(name)),
                    _AddChip(
                        key: const Key('rates-add-new'),
                        label: tr('New'),
                        onTap: () => setState(() => _adding = true)),
                  ]),
                  if (_adding) ...[
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                          child: TextField(
                              key: const Key('rates-new-name'),
                              controller: _newName,
                              autofocus: true,
                              textCapitalization: TextCapitalization.words,
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(60)
                              ],
                              onSubmitted: _addPiece,
                              decoration: InputDecoration(
                                  labelText: tr('Device name')))),
                      const SizedBox(width: 8),
                      AddButton(
                          key: const Key('rates-new-add'),
                          onPressed: () => _addPiece(_newName.text)),
                    ]),
                  ],
                ])),
            const SizedBox(height: 12),
            NoteBox(
                icon: Icons.info_outline_rounded,
                title: tr('How these are used'),
                body: tr(
                    'A new order fills in these rates. A flight can have its own rates, and each order can still be changed. Orders already booked keep their price.')),
            if (_error != null) ...[
              const SizedBox(height: 12),
              ErrorNote(message: _error!),
            ],
          ],
        ]);
  }
}

/// "+ Name" chip with a dashed outline.
class _AddChip extends StatelessWidget {
  const _AddChip({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
      button: true,
      child: DashedOutline(
          radius: 999,
          color: AppColors.primary,
          child: Material(
              color: Colors.transparent,
              shape: const StadiumBorder(),
              child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: onTap,
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 0, 14, 0),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.add_rounded,
                                size: 16, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(label,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary)),
                          ])))))));
}
