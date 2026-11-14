import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ui.dart';

/// The couriers the hub picks from when it sorts a customer. Hub pickup is
/// always offered and cannot be removed. Each change is saved at once.
class PartnersScreen extends StatefulWidget {
  const PartnersScreen({super.key});

  @override
  State<PartnersScreen> createState() => _PartnersScreenState();
}

class _PartnersScreenState extends State<PartnersScreen> {
  List<String>? _partners;
  String? _error;
  var _loading = true;
  var _saving = false;
  final _name = TextEditingController();

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final partners = await AppScope.of(context).settings.deliveryPartners();
      if (mounted) setState(() => _partners = partners);
    } on ApiException catch (error) {
      if (mounted && error.status != 401) {
        setState(() => _error = error.message);
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save(List<String> next) async {
    final before = _partners;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _partners = next;
      _saving = true;
    });
    try {
      final saved =
          await AppScope.of(context).settings.saveDeliveryPartners(next);
      if (mounted) setState(() => _partners = saved);
    } on ApiException catch (error) {
      if (mounted) setState(() => _partners = before);
      if (error.status != 401) {
        messenger.showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _add() async {
    final name = _name.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    final list = _partners ?? const <String>[];
    if (name.isEmpty) return;
    if (name.toLowerCase() == 'hub pickup' ||
        list.any((p) => p.toLowerCase() == name.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr('{name} is already on the list', {'name': name}))));
      return;
    }
    _name.clear();
    FocusScope.of(context).unfocus();
    await _save([...list, name]);
  }

  Future<void> _remove(String name) async {
    final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(tr('Remove {name}?', {'name': name})),
              content: Text(tr(
                  'The hub will not see it when sorting. Orders already booked with it keep it.')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(tr('Cancel'))),
                FilledButton(
                    key: const Key('partner-remove-confirm'),
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(tr('Remove'))),
              ],
            ));
    if (yes != true || !mounted) return;
    await _save([...?_partners]..remove(name));
  }

  void _reorder(int from, int to) {
    final list = [...?_partners];
    list.insert(to, list.removeAt(from));
    _save(list);
  }

  @override
  Widget build(BuildContext context) {
    final partners = _partners;
    return WorkspaceScaffold(
      title: tr('Delivery partners'),
      subtitle: tr('Settings'),
      onRefresh: _load,
      children: [
        if (_loading && partners == null) const LinearProgressIndicator(),
        if (_error != null) ErrorNote(message: _error!, onRetry: _load),
        if (partners != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Text(
                tr('The hub picks one of these when it sorts a customer.'),
                style: const TextStyle(fontSize: 13.5, color: AppColors.muted)),
          ),
          PaperCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                onReorderItem: _saving ? (_, __) {} : _reorder,
                children: [
                  for (var i = 0; i < partners.length; i++)
                    _PartnerRow(
                        key: ValueKey('partner-${partners[i]}'),
                        index: i,
                        name: partners[i],
                        onRemove: _saving ? null : () => _remove(partners[i])),
                ],
              ),
              const Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: AppColors.lineSoft),
              Padding(
                padding: const EdgeInsets.fromLTRB(44, 12, 16, 12),
                child: Row(children: [
                  const IconBadge(Icons.storefront_outlined,
                      tone: ChipTone.neutral),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr('Hub pickup'),
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600)),
                          Text(tr('Customer collects at the hub'),
                              style: const TextStyle(
                                  fontSize: 12.5, color: AppColors.muted)),
                        ]),
                  ),
                  Text(tr('Always on'),
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.muted)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          FormSection(title: tr('Add a partner'), children: [
            TextField(
                key: const Key('partner-name'),
                controller: _name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _add(),
                maxLength: 60,
                decoration: InputDecoration(
                    labelText: tr('Name'), hintText: tr('e.g. eCourier'))),
            const SizedBox(height: 4),
            AppButton(
                key: const Key('partner-add'),
                label: tr('Add partner'),
                icon: Icons.add_rounded,
                kind: AppButtonKind.quiet,
                busy: _saving,
                onPressed: _name.text.trim().isEmpty || _saving ? null : _add),
          ]),
        ],
      ],
    );
  }
}

class _PartnerRow extends StatelessWidget {
  const _PartnerRow(
      {super.key,
      required this.index,
      required this.name,
      required this.onRemove});

  final int index;
  final String name;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.card,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 6, 6),
          child: Row(children: [
            ReorderableDragStartListener(
              index: index,
              child: Tooltip(
                message: tr('Drag to reorder'),
                child: const SizedBox(
                    width: 40,
                    height: 48,
                    child: Icon(Icons.drag_indicator_rounded,
                        size: 20, color: AppColors.faint)),
              ),
            ),
            const IconBadge(Icons.local_shipping_outlined,
                tone: ChipTone.neutral),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    Text(tr('Courier'),
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.muted)),
                  ]),
            ),
            IconButton(
                key: Key('partner-remove-$name'),
                tooltip: tr('Remove {name}', {'name': name}),
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 21, color: AppColors.muted)),
          ]),
        ),
      );
}
