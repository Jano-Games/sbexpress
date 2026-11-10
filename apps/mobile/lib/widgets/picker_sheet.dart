import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_colors.dart';
import 'flight_parts.dart' show LetterAvatar;
import 'ui.dart';

/// What [PickerSheet] pops when "New customer" is tapped.
const pickerNewCustomer = '\u0000new';

/// A searchable list of choices with a "New customer" button at the top.
/// Pops the chosen value, or [pickerNewCustomer] for the button.
class PickerSheet extends StatefulWidget {
  const PickerSheet(
      {super.key,
      required this.title,
      required this.options,
      this.selected,
      this.subtitle});
  final String title;

  /// A line under the title, e.g. which device is being assigned.
  final String? subtitle;
  final List<({String value, String title, String subtitle})> options;
  final String? selected;
  @override
  State<PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<PickerSheet> {
  var _query = '';
  @override
  Widget build(BuildContext context) {
    final options = widget.options.where((item) =>
        '${item.title} ${item.subtitle}'.toLowerCase().contains(_query));
    return Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .72,
            child: Column(children: [
              Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
                  child: Row(children: [
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(widget.title,
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w600)),
                          if (widget.subtitle != null)
                            Text(widget.subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.35,
                                    color: AppColors.muted)),
                        ])),
                    TextButton.icon(
                        key: const Key('picker-new-customer'),
                        onPressed: () =>
                            Navigator.pop(context, pickerNewCustomer),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(tr('New customer'))),
                    IconButton(
                        tooltip: tr('Close'),
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded)),
                  ])),
              Padding(
                  padding: const EdgeInsets.all(20),
                  child: TextField(
                      decoration: InputDecoration(
                          hintText: tr('Search'),
                          prefixIcon: const Icon(Icons.search_rounded)),
                      onChanged: (value) =>
                          setState(() => _query = value.trim().toLowerCase()))),
              Expanded(
                  child: options.isEmpty
                      ? EmptyNote(
                          title: tr('No results found'),
                          body: tr('Try another name or code.'))
                      : ListView(children: [
                          for (final item in options)
                            ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 4),
                                leading:
                                    LetterAvatar.customer(item.title, size: 40),
                                title: Text(item.title),
                                subtitle: Text(item.subtitle),
                                trailing: item.value == widget.selected
                                    ? const Icon(Icons.check_rounded,
                                        color: AppColors.primary)
                                    : null,
                                onTap: () =>
                                    Navigator.pop(context, item.value)),
                        ])),
            ])));
  }
}
