import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/flyer.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ui.dart';

class FlyerFormScreen extends StatefulWidget {
  const FlyerFormScreen({super.key});

  @override
  State<FlyerFormScreen> createState() => _FlyerFormScreenState();
}

class _FlyerFormScreenState extends State<FlyerFormScreen> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _bd = TextEditingController();
  final _cn = TextEditingController();
  final _university = TextEditingController();
  final _batch = TextEditingController();
  final _program = TextEditingController();
  final _wechat = TextEditingController();
  final _emergency = TextEditingController();
  String? _error;
  var _busy = false;

  @override
  void dispose() {
    for (final controller in [
      _first,
      _last,
      _bd,
      _cn,
      _university,
      _batch,
      _program,
      _wechat,
      _emergency
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_first.text.trim().isEmpty) {
      setState(() => _error = tr('Enter the first name.'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.of(context).flyers.create(FlyerDraft(
            firstName: _first.text.trim(),
            lastName: _last.text.trim(),
            bdPhone: _bd.text.trim(),
            cnPhone: _cn.text.trim(),
            university: _university.text.trim(),
            batch: _batch.text.trim(),
            program: _program.text.trim(),
            wechat: _wechat.text.trim(),
            emergencyContact: _emergency.text.trim(),
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
        title: tr('New flyer'),
        root: false,
        footer: ActionFooter(
            child: AppButton(
                label: tr('Save flyer'),
                kind: AppButtonKind.current,
                busy: _busy,
                onPressed: _save)),
        children: [
          Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                  tr(
                      'A name is enough to create the profile. Other fields can stay blank.'),
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.muted, height: 1.5))),
          TextField(
              controller: _first,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: tr('First name'))),
          const SizedBox(height: 8),
          TextField(
              controller: _last,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: tr('Last name'))),
          const SizedBox(height: 8),
          TextField(
              controller: _bd,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: tr('Bangladesh phone'))),
          const SizedBox(height: 8),
          TextField(
              controller: _cn,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: tr('China phone'))),
          const SizedBox(height: 8),
          TextField(
              controller: _university,
              decoration: InputDecoration(labelText: tr('University'))),
          const SizedBox(height: 8),
          TextField(
              controller: _program,
              decoration: InputDecoration(labelText: tr('Program'))),
          const SizedBox(height: 8),
          TextField(
              controller: _batch,
              decoration: InputDecoration(labelText: tr('Batch'))),
          const SizedBox(height: 8),
          TextField(
              controller: _wechat,
              decoration: const InputDecoration(labelText: 'WeChat')),
          const SizedBox(height: 8),
          TextField(
              controller: _emergency,
              decoration: InputDecoration(labelText: tr('Emergency contact'))),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ],
        ]);
  }
}
