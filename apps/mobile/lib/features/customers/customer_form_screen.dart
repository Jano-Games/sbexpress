import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/customer.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/finance_parts.dart';
import '../../widgets/ui.dart';

class CustomerFormScreen extends StatefulWidget {
  const CustomerFormScreen({super.key});

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  var _terms = 'instant';
  String? _error;
  var _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = tr('Enter the customer name.'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.of(context).customers.create(CustomerDraft(
            name: _name.text.trim(),
            phone: _phone.text.trim(),
            address: _address.text.trim(),
            terms: _terms,
          ));
      if (!mounted) return;
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
    return WorkspaceScaffold(
        title: tr('New customer'),
        root: false,
        footer: ActionFooter(
            child: AppButton(
                key: const Key('customer-save'),
                label: tr('Save customer'),
                icon: Icons.check_rounded,
                kind: AppButtonKind.current,
                busy: _busy,
                onPressed: _save)),
        children: [
          HintNote(
              text: tr(
                  'The server assigns the code. Payment accounts are not added here.')),
          const SizedBox(height: 16),
          PaperCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                FieldLabel(tr('Name')),
                TextField(
                    key: const Key('customer-name'),
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration:
                        InputDecoration(hintText: tr('Shop or person name'))),
                const SizedBox(height: 14),
                FieldLabel(tr('Phone')),
                TextField(
                    key: const Key('customer-phone'),
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                        hintText: '01XXXXXXXXX',
                        prefixIcon: Icon(Icons.call_outlined, size: 20))),
                const SizedBox(height: 14),
                FieldLabel(tr('Address')),
                TextField(
                    key: const Key('customer-address'),
                    controller: _address,
                    minLines: 2,
                    maxLines: 3,
                    decoration:
                        InputDecoration(hintText: tr('House, road and area'))),
              ])),
          const SizedBox(height: 20),
          SectionTitle(title: tr('Billing terms')),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: OptionCard(
                    key: const Key('customer-terms-instant'),
                    icon: Icons.bolt_rounded,
                    tone: ChipTone.blue,
                    title: tr('Instant'),
                    subtitle: tr('Billed per shipment'),
                    selected: _terms == 'instant',
                    onTap: () => setState(() => _terms = 'instant'))),
            const SizedBox(width: 10),
            Expanded(
                child: OptionCard(
                    key: const Key('customer-terms-monthly'),
                    icon: Icons.calendar_month_outlined,
                    tone: ChipTone.neutral,
                    title: tr('Monthly'),
                    subtitle: tr('One statement a month'),
                    selected: _terms == 'monthly',
                    onTap: () => setState(() => _terms = 'monthly'))),
          ]),
          if (_error != null) ...[
            const SizedBox(height: 12),
            ErrorNote(message: _error!),
          ],
        ]);
  }
}
