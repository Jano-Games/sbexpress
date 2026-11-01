import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../theme/app_colors.dart';
import 'team_parts.dart' show fieldSign, fieldSignConstraints, plainNumber;

/// "1250" or "12.5" for a rate field; empty for nothing set.
String rateText(double? value) =>
    value == null || value <= 0 ? '' : plainNumber(value);

String currencySign(String currency) => currency == 'CNY' ? '¥' : '৳';

/// Money field for a rate: the currency sign in front and a unit such as
/// "per kg" or "/ pc" at the end.
class RateField extends StatelessWidget {
  const RateField(
      {super.key,
      required this.controller,
      required this.currency,
      required this.unit,
      this.onChanged,
      this.large = false});
  final TextEditingController controller;
  final String currency, unit;
  final ValueChanged<String>? onChanged;
  final bool large;

  @override
  Widget build(BuildContext context) => TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      style: TextStyle(
          fontSize: large ? 20 : 16,
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()]),
      decoration: InputDecoration(
          hintText: '0',
          prefixIcon: fieldSign(currencySign(currency), size: large ? 18 : 15),
          prefixIconConstraints: fieldSignConstraints,
          suffixIcon: Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: Text(unit,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted))),
          suffixIconConstraints: const BoxConstraints(minWidth: 0),
          contentPadding:
              EdgeInsets.fromLTRB(4, large ? 15 : 12, 8, large ? 15 : 12)));
}

/// One device category with its piece price, and an optional remove button.
class PiecePriceRow extends StatelessWidget {
  const PiecePriceRow(
      {super.key,
      required this.name,
      required this.controller,
      this.onChanged,
      this.onRemove,
      this.leading});
  final String name;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onRemove;

  /// Between the name and the price, e.g. a count stepper.
  final Widget? leading;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: LayoutBuilder(builder: (context, box) {
        final label = Text(name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 15, height: 1.3, fontWeight: FontWeight.w600));
        final price = Semantics(
            label: tr('{name} price', {'name': name}),
            child: RateField(
                key: ValueKey('piece-price-$name'),
                controller: controller,
                currency: 'BDT',
                unit: tr('/ pc'),
                onChanged: onChanged));
        final remove = onRemove == null
            ? null
            : IconButton(
                key: ValueKey('piece-remove-$name'),
                tooltip: tr('Remove {name}', {'name': name}),
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded,
                    size: 20, color: AppColors.muted));
        // On a narrow phone a stepper and a price leave the name no room,
        // so it goes on its own line.
        if (leading != null && box.maxWidth < 340) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                label,
                const SizedBox(height: 6),
                Row(children: [
                  leading!,
                  const SizedBox(width: 8),
                  Expanded(child: price),
                  if (remove != null) remove,
                ]),
              ]);
        }
        return Row(children: [
          Expanded(child: label),
          if (leading != null) ...[leading!, const SizedBox(width: 8)],
          SizedBox(width: 132, child: price),
          if (remove != null) remove,
        ]);
      }));
}

/// − count + for a number of pieces.
class CountStepper extends StatelessWidget {
  const CountStepper(
      {super.key,
      required this.count,
      required this.onChanged,
      this.min = 1,
      this.max = 20,
      required this.name});
  final int count, min, max;
  final ValueChanged<int> onChanged;
  final String name;

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, String tip, int? next, Key key) => SizedBox(
        width: 40,
        height: 44,
        child: IconButton(
            key: key,
            tooltip: tip,
            padding: EdgeInsets.zero,
            onPressed: next == null ? null : () => onChanged(next),
            icon: Icon(icon, size: 18)));
    return Container(
        decoration: BoxDecoration(
            border: Border.all(color: AppColors.field),
            borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          button(Icons.remove_rounded, tr('Fewer {name}', {'name': name}),
              count > min ? count - 1 : null, ValueKey('count-minus-$name')),
          Semantics(
              liveRegion: true,
              child: SizedBox(
                  width: 22,
                  child: Text('$count',
                      key: ValueKey('count-$name'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)))),
          button(Icons.add_rounded, tr('More {name}', {'name': name}),
              count < max ? count + 1 : null, ValueKey('count-plus-$name')),
        ]));
  }
}
