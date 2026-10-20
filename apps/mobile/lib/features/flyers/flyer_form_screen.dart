import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/flyer.dart';
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
    for (final controller in [_first, _last, _bd, _cn, _university, _batch, _program, _wechat, _emergency]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_first.text.trim().isEmpty) {
      setState(() => _error = 'নামের প্রথম অংশ দিন।');
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
    return Scaffold(
      appBar: const BackTitle(title: 'নতুন ফ্লায়ার'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(pageGutter, 8, pageGutter, 32),
        children: [
          const PageHeader(title: 'নতুন ফ্লায়ার', subtitle: 'নাম দিয়ে প্রোফাইল খোলে। বাকি ঘর খালি রাখা যায়।'),
          TextField(controller: _first, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'নামের প্রথম অংশ')),
          const SizedBox(height: 8),
          TextField(controller: _last, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'নামের শেষ অংশ')),
          const SizedBox(height: 8),
          TextField(controller: _bd, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'বাংলাদেশ ফোন')),
          const SizedBox(height: 8),
          TextField(controller: _cn, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'চায়না ফোন')),
          const SizedBox(height: 8),
          TextField(controller: _university, decoration: const InputDecoration(labelText: 'বিশ্ববিদ্যালয়')),
          const SizedBox(height: 8),
          TextField(controller: _program, decoration: const InputDecoration(labelText: 'প্রোগ্রাম')),
          const SizedBox(height: 8),
          TextField(controller: _batch, decoration: const InputDecoration(labelText: 'ব্যাচ')),
          const SizedBox(height: 8),
          TextField(controller: _wechat, decoration: const InputDecoration(labelText: 'WeChat')),
          const SizedBox(height: 8),
          TextField(controller: _emergency, decoration: const InputDecoration(labelText: 'ইমার্জেন্সি কন্টাক্ট')),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ],
          const SizedBox(height: 16),
          AppButton(label: 'সেভ করুন', kind: AppButtonKind.current, busy: _busy, onPressed: _save),
        ],
      ),
    );
  }
}
