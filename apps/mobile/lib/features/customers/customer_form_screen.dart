import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/customer.dart';
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
      setState(() => _error = 'কাস্টমারের নাম দিন।');
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
        title: 'নতুন কাস্টমার',
        root: false,
        footer: ActionFooter(
            child: AppButton(
                label: 'সেভ করুন',
                kind: AppButtonKind.current,
                busy: _busy,
                onPressed: _save)),
        children: [
          const Padding(
              padding: EdgeInsets.only(bottom: 20),
              child: Text(
                  'কোড সার্ভার দেবে। পেমেন্ট অ্যাকাউন্ট এখানে যোগ করা হয় না।',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.muted, height: 1.5))),
          TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'নাম')),
          const SizedBox(height: 8),
          TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'ফোন')),
          const SizedBox(height: 8),
          TextField(
              controller: _address,
              decoration: const InputDecoration(labelText: 'ঠিকানা')),
          const SizedBox(height: 12),
          const Text('বিলিং টার্ম',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ChoiceChips(
            options: const [
              (value: 'instant', label: 'সাথে সাথে'),
              (value: 'monthly', label: 'মাসিক'),
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
