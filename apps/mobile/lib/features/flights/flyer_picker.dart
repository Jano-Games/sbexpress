import 'package:flutter/material.dart';

import '../../data/models/flyer.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/flight_parts.dart' show LetterAvatar;
import '../../widgets/flow_parts.dart' show SheetHeader, showFlowSheet;
import '../../widgets/ui.dart';

/// The flyers chosen in the sheet, or a wish to make a new one.
typedef FlyerPick = ({Set<String> names, bool addNew});

/// A list of flyers to tick, with search. Null when closed without Done.
Future<FlyerPick?> showFlyerPicker(BuildContext context,
        {required List<FlyerSummary> flyers, required Set<String> picked}) =>
    showFlowSheet<FlyerPick>(
        context, (_) => FlyerPickerSheet(flyers: flyers, picked: picked));

class FlyerPickerSheet extends StatefulWidget {
  const FlyerPickerSheet(
      {super.key, required this.flyers, required this.picked});
  final List<FlyerSummary> flyers;
  final Set<String> picked;

  @override
  State<FlyerPickerSheet> createState() => _FlyerPickerSheetState();
}

class _FlyerPickerSheetState extends State<FlyerPickerSheet> {
  late final _picked = {...widget.picked};
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<FlyerSummary> get _shown {
    final query = _search.text.trim().toLowerCase();
    final digits = query.replaceAll(RegExp(r'\D'), '');
    return [
      for (final flyer in widget.flyers)
        if (query.isEmpty ||
            flyer.name.toLowerCase().contains(query) ||
            (digits.isNotEmpty &&
                flyer.bdPhone.replaceAll(RegExp(r'\D'), '').contains(digits)))
          flyer
    ];
  }

  void _toggle(String name) => setState(() {
        if (!_picked.remove(name)) _picked.add(name);
      });

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    final count = _picked.length;
    return ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.86),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetHeader(
                  title: tr('Choose flyers'),
                  subtitle: tr('Pick one or more for this ticket')),
              Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: TextField(
                      key: const Key('flyer-search'),
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                          hintText: tr('Search name or phone'),
                          prefixIcon:
                              const Icon(Icons.search_rounded, size: 20)))),
              Flexible(
                  child: shown.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                              tr('No flyer matches "{query}".',
                                  {'query': _search.text.trim()}),
                              style: const TextStyle(color: AppColors.muted)))
                      : ListView(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          children: [
                              for (final flyer in shown)
                                _FlyerRow(
                                    flyer: flyer,
                                    picked: _picked.contains(flyer.name),
                                    onTap: () => _toggle(flyer.name)),
                            ])),
              Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppButton(
                            key: const Key('flyer-picker-new'),
                            label: tr('Add a new flyer'),
                            icon: Icons.person_add_alt_1_rounded,
                            kind: AppButtonKind.quiet,
                            onPressed: () => Navigator.of(context)
                                .pop((names: _picked, addNew: true))),
                        const SizedBox(height: 10),
                        AppButton(
                            key: const Key('flyer-picker-done'),
                            label: count == 0
                                ? tr('Done')
                                : trn(count, 'Done · {n} chosen',
                                    'Done · {n} chosen'),
                            icon: Icons.check_rounded,
                            kind: AppButtonKind.current,
                            onPressed: () => Navigator.of(context)
                                .pop((names: _picked, addNew: false))),
                      ])),
            ]));
  }
}

class _FlyerRow extends StatelessWidget {
  const _FlyerRow(
      {required this.flyer, required this.picked, required this.onTap});
  final FlyerSummary flyer;
  final bool picked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
      checked: picked,
      child: InkWell(
          key: ValueKey('flyer-pick-${flyer.name}'),
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 60),
              child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(children: [
                    Checkbox(value: picked, onChanged: (_) => onTap()),
                    const SizedBox(width: 4),
                    LetterAvatar(flyer.name,
                        size: 38,
                        color: picked
                            ? AppColors.primarySoft
                            : AppColors.neutralSoft,
                        foreground:
                            picked ? AppColors.primary : AppColors.inkSoft),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(flyer.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600)),
                          if (flyer.bdPhone.isNotEmpty)
                            Text(flyer.bdPhone,
                                style: const TextStyle(
                                    fontSize: 12.5, color: AppColors.muted)),
                        ])),
                  ])))));
}

/// The chosen flyers as chips in one field, like a dropdown.
class FlyerPickerField extends StatelessWidget {
  const FlyerPickerField(
      {super.key,
      required this.picked,
      required this.onTap,
      required this.onRemove,
      this.error});
  final List<String> picked;
  final VoidCallback? onTap;
  final ValueChanged<String> onRemove;
  final String? error;

  @override
  Widget build(BuildContext context) => InkWell(
      key: const Key('flight-flyers'),
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: InputDecorator(
          isEmpty: picked.isEmpty,
          decoration: InputDecoration(
              hintText: tr('Tap to choose'),
              errorText: error,
              suffixIcon: const Icon(Icons.expand_more_rounded)),
          child: picked.isEmpty
              ? null
              : Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final name in picked)
                    InputChip(
                        key: ValueKey('flight-flyer-$name'),
                        label: Text(name),
                        labelStyle: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryInk),
                        backgroundColor: AppColors.primarySoft,
                        side: BorderSide.none,
                        deleteIcon: const Icon(Icons.close_rounded, size: 16),
                        deleteButtonTooltipMessage:
                            tr('Remove {name}', {'name': name}),
                        onDeleted: () => onRemove(name)),
                ])));
}
