import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/workspace.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ui.dart';
import '../admin/money_format.dart';
import 'pay_method_form_screen.dart';
import 'staff_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  SetupStatus? _setup;
  SettingsSnapshot? _settings;
  List<PayMethodInfo> _methods = const [];
  List<StaffAccount> _staff = const [];
  String? _error;
  var _loading = true;
  var _busy = false;
  final _rate = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _rate.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final settingsRepo = AppScope.of(context).settings;
      final setup = await settingsRepo.setup();
      final current = await settingsRepo.current();
      final methods = await settingsRepo.payMethods();
      final staff = await settingsRepo.staff();
      if (!mounted) return;
      setState(() {
        _setup = setup;
        _settings = current;
        _methods = methods;
        _staff = staff;
        if (_rate.text.isEmpty && setup.rateConfirmed) _rate.text = current.rate.toString();
      });
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(PayMethodInfo method) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.of(context).settings.setPayMethodEnabled(method.id, enabled: !method.enabled);
      await _load();
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveRate() async {
    final rate = double.tryParse(_rate.text.trim());
    if (rate == null || rate <= 0) {
      setState(() => _error = 'আসল CNY রেট লিখুন। খালি বা ০ সেভ হবে না।');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.of(context).settings.saveRate(rate);
      await _load();
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final setup = _setup;
    final settings = _settings;
    return Scaffold(
      appBar: const BackTitle(title: 'সেটিংস'),
      body: RefreshIndicator(
        color: AppColors.teal,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(pageGutter, 8, pageGutter, 32),
          children: [
            const PageHeader(title: 'সেটিংস', subtitle: 'CNY রেট, বিকাশ বা ব্যাংক, এবং স্টাফের রোল ও পাসওয়ার্ড।'),
            if (_loading && setup == null) const LinearProgressIndicator(color: AppColors.teal, backgroundColor: AppColors.tealSoft),
            if (_error != null) ...[
              ErrorNote(message: _error!, onRetry: _load),
              const SizedBox(height: 12),
            ],
            if (setup != null && settings != null) ...[
              const SectionTitle(title: 'সেটআপ'),
              _Check(label: 'CNY রেট নিশ্চিত', ok: setup.rateConfirmed),
              _Check(label: 'ফান্ড অ্যাকাউন্ট ${setup.accounts}', ok: setup.accounts > 0),
              _Check(label: 'পেমেন্ট মেথড ${setup.paymentMethods}', ok: setup.paymentMethods > 0),
              _Check(label: 'সক্রিয় স্টাফ ${setup.users}', ok: setup.users > 0),
              _Check(label: 'স্টোরেজ', ok: setup.storageConfigured),
              _Check(label: 'মিডিয়া ক্লিনআপ', ok: setup.cleanupEnabled),
              if (setup.lastCleanupAt != null) Text('শেষ ক্লিনআপ ${setup.lastCleanupAt}', style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 16),
              const SectionTitle(title: 'CNY রেট', subtitle: '৳ প্রতি ¥১। যে রেট ব্যবসা ব্যবহার করে সেটাই লিখুন।'),
              Text('এখন সেভ করা রেট ${formatBdt(settings.rate)}', style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 8),
              TextField(controller: _rate, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'নতুন রেট')),
              const SizedBox(height: 8),
              AppButton(label: 'রেট সেভ করুন', kind: AppButtonKind.current, busy: _busy, onPressed: _saveRate),
              const SizedBox(height: 8),
              Text('ওজন অ্যালার্ট ${settings.threshold} kg-এর বেশি হলে।', style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 16),
              const SectionTitle(title: 'পেমেন্ট মেথড', subtitle: 'ট্র্যাকিং পেজে যা দেখায়। নম্বর আন্দাজ করবেন না।'),
              if (_methods.isEmpty) const EmptyNote(title: 'মেথড নেই', body: 'আসল বিকাশ বা ব্যাংক নম্বর দিয়ে যোগ করুন।'),
              for (final method in _methods) ...[
                PaperCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(method.title, style: const TextStyle(fontWeight: FontWeight.w700))),
                          StatusPill(label: method.enabled ? 'চালু' : 'বন্ধ', tone: method.enabled ? ChipTone.green : ChipTone.neutral),
                        ],
                      ),
                      Text('${method.currency} · ${method.detail}', style: const TextStyle(color: AppColors.muted)),
                      const SizedBox(height: 8),
                      AppButton(
                        label: method.enabled ? 'বন্ধ করুন' : 'চালু করুন',
                        kind: AppButtonKind.quiet,
                        busy: _busy,
                        onPressed: () => _toggle(method),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 8),
              AppButton(
                label: 'নতুন মেথড',
                kind: AppButtonKind.current,
                onPressed: () async {
                  final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const PayMethodFormScreen()));
                  if (saved == true && mounted) await _load();
                },
              ),
              const SizedBox(height: 16),
              const SectionTitle(title: 'স্টাফ'),
              for (final person in _staff) ...[
                PaperCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(person.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(person.email, style: const TextStyle(color: AppColors.muted)),
                      const SizedBox(height: 6),
                      StatusPill(label: person.active ? (person.role == 'hub' ? 'হাব' : 'অ্যাডমিন') : 'নিষ্ক্রিয়', tone: person.active ? ChipTone.teal : ChipTone.neutral),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              AppButton(
                label: 'স্টাফ ব্যবস্থাপনা',
                kind: AppButtonKind.teal,
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const StaffScreen())),
              ),
              const SizedBox(height: 8),
              const Text('নিজের পাসওয়ার্ড বদলালে সব সেশন কেটে যায়।', style: TextStyle(color: AppColors.muted, height: 1.35)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.label, required this.ok});

  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle : Icons.radio_button_unchecked, color: ok ? AppColors.ok : AppColors.muted),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}
