import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/customer.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
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
                label: tr('Save'),
                kind: AppButtonKind.current,
                busy: _busy,
                onPressed: _save)),
        children: [
          Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                  tr(
                      'The server assigns the code. Payment accounts are not added here.'),
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.muted, height: 1.5))),
          TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: tr('Name'))),
          const SizedBox(height: 8),
          TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: tr('Phone'))),
          const SizedBox(height: 8),
          TextField(
              controller: _address,
              decoration: InputDecoration(labelText: tr('Address'))),
          const SizedBox(height: 12),
          Text(tr('Billing terms'),
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ChoiceChips(
            options: [
              (value: 'instant', label: tr('Instant')),
              (value: 'monthly', label: tr('Monthly')),
            ],
            selected: _terms,
            onSelected: (value) => setState(() => _terms = value),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ],
        ]);
  }
}
