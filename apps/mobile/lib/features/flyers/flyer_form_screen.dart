import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/flyer.dart';
import '../../l10n/l10n.dart';
import '../../widgets/team_parts.dart';
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

  Widget _field(String label, TextEditingController controller,
          {TextInputType? keyboard,
          TextCapitalization caps = TextCapitalization.none}) =>
      LabeledField(
          label: label,
          child: TextField(
              controller: controller,
              keyboardType: keyboard,
              textCapitalization: caps,
              textInputAction: TextInputAction.next));

  @override
  Widget build(BuildContext context) {
    return WorkspaceScaffold(
        title: tr('New flyer'),
        subtitle: tr('Profiles and travel documents'),
        root: false,
        footer: FooterActions(
            error: _error,
            child: AppButton(
                label: tr('Save flyer'),
                icon: Icons.check_rounded,
                kind: AppButtonKind.current,
                busy: _busy,
                onPressed: _save)),
        children: [
          FormCard(title: tr('Personal details'), children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: _field(tr('First name'), _first,
                      caps: TextCapitalization.words)),
              const SizedBox(width: 10),
              Expanded(
                  child: _field(tr('Last name'), _last,
                      caps: TextCapitalization.words)),
            ]),
          ]),
          const SizedBox(height: 14),
          FormCard(title: tr('Contact'), children: [
            _field(tr('Bangladesh phone'), _bd, keyboard: TextInputType.phone),
            _field(tr('China phone'), _cn, keyboard: TextInputType.phone),
            _field('WeChat', _wechat),
            _field(tr('Emergency contact'), _emergency),
          ]),
          const SizedBox(height: 14),
          FormCard(title: tr('Study'), children: [
            _field(tr('University'), _university),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _field(tr('Program'), _program)),
              const SizedBox(width: 10),
              Expanded(child: _field(tr('Batch'), _batch)),
            ]),
          ]),
          const SizedBox(height: 14),
          TipNote(
              text: tr(
                  'A name is enough to create the profile. Other fields can stay blank.')),
        ]);
  }
}
