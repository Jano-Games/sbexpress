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
        if (_rate.text.isEmpty && setup.rateConfirmed) {
          _rate.text = current.rate.toString();
        }
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
      await AppScope.of(context)
          .settings
          .setPayMethodEnabled(method.id, enabled: !method.enabled);
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

  Future<void> _openStaff() async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const StaffScreen()));
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final setup = _setup;
    final settings = _settings;
    return Scaffold(
        appBar: const BackTitle(title: 'সেটিংস'),
        body: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.fromLTRB(pageGutter, 12, pageGutter, 32),
                children: [
                  const Text('পেমেন্ট, এক্সচেঞ্জ রেট ও আপনার টিম',
                      style: TextStyle(color: AppColors.muted, fontSize: 13)),
                  const SizedBox(height: 24),
                  if (_loading && setup == null)
                    const LinearProgressIndicator(),
                  if (_error != null)
                    ErrorNote(message: _error!, onRetry: _load),
                  if (setup != null && settings != null) ...[
                    const SectionTitle(title: 'এক্সচেঞ্জ রেট'),
                    PaperCard(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Row(children: [
                            const Icon(Icons.currency_exchange_rounded,
                                color: AppColors.teal, size: 21),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Text(
                                    '1 CNY = ${formatBdt(settings.rate)}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 17))),
                          ]),
                          const SizedBox(height: 6),
                          const Text('নতুন লেনদেনে এই রেট ব্যবহার হবে।',
                              style: TextStyle(
                                  color: AppColors.muted, fontSize: 12)),
                          const SizedBox(height: 16),
                          Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                    child: TextField(
                                        controller: _rate,
                                        keyboardType: const TextInputType
                                            .numberWithOptions(decimal: true),
                                        decoration: const InputDecoration(
                                            labelText: 'প্রতি CNY-তে BDT'))),
                                const SizedBox(width: 12),
                                AppButton(
                                    label: 'সেভ',
                                    expand: false,
                                    busy: _busy,
                                    onPressed: _saveRate),
                              ]),
                        ])),
                    const SizedBox(height: 24),
                    SectionTitle(
                        title: 'পেমেন্ট মেথড',
                        subtitle: 'Customer link-এ প্রদর্শিত হবে',
                        action: TextButton.icon(
                            icon: const Icon(Icons.add_rounded, size: 17),
                            label: const Text('নতুন'),
                            onPressed: () async {
                              final saved = await Navigator.of(context)
                                  .push<bool>(MaterialPageRoute(
                                      builder: (_) =>
                                          const PayMethodFormScreen()));
                              if (saved == true && mounted) await _load();
                            })),
                    if (_methods.isEmpty)
                      const EmptyNote(
                          title: 'মেথড নেই',
                          body: 'বিকাশ, ব্যাংক বা ওয়ালেটের তথ্য যোগ করুন।')
                    else
                      SurfaceGroup(children: [
                        for (final method in _methods)
                          SwitchListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 6),
                              value: method.enabled,
                              onChanged: _busy ? null : (_) => _toggle(method),
                              title: Text(method.title,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500)),
                              subtitle: Text(
                                  '${method.currency} · ${method.detail}',
                                  style: const TextStyle(
                                      fontSize: 12, color: AppColors.muted))),
                      ]),
                    const SizedBox(height: 24),
                    const SectionTitle(title: 'টিম ও অপারেশন'),
                    SurfaceGroup(children: [
                      MenuRow(
                          title: 'স্টাফ ব্যবস্থাপনা',
                          subtitle:
                              '${_staff.where((person) => person.active).length} জন সক্রিয় · অ্যাক্সেস ও পাসওয়ার্ড',
                          icon: Icons.people_outline_rounded,
                          onTap: _openStaff),
                      Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(children: [
                            const Icon(Icons.scale_outlined,
                                size: 21, color: AppColors.muted),
                            const SizedBox(width: 14),
                            Expanded(
                                child: Text(
                                    'ওজনের পার্থক্য ${settings.threshold} kg ছাড়ালে সতর্কতা',
                                    style: const TextStyle(fontSize: 13))),
                          ])),
                    ]),
                    const SizedBox(height: 24),
                    PaperCard(
                        padding: EdgeInsets.zero,
                        child: ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            leading: const Icon(Icons.checklist_rounded,
                                color: AppColors.muted, size: 22),
                            title: const Text('সিস্টেম সেটআপ',
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w500)),
                            subtitle: const Text('সংযোগ ও প্রয়োজনীয় সেটিংস',
                                style: TextStyle(
                                    fontSize: 12, color: AppColors.muted)),
                            childrenPadding:
                                const EdgeInsets.fromLTRB(16, 4, 16, 16),
                            shape: const Border(),
                            collapsedShape: const Border(),
                            children: [
                              _Check(
                                  label: 'CNY রেট নিশ্চিত',
                                  ok: setup.rateConfirmed),
                              _Check(
                                  label: 'ফান্ড অ্যাকাউন্ট ${setup.accounts}',
                                  ok: setup.accounts > 0),
                              _Check(
                                  label: 'পেমেন্ট মেথড ${setup.paymentMethods}',
                                  ok: setup.paymentMethods > 0),
                              _Check(
                                  label: 'সক্রিয় স্টাফ ${setup.users}',
                                  ok: setup.users > 0),
                              _Check(
                                  label: 'স্টোরেজ',
                                  ok: setup.storageConfigured),
                              _Check(
                                  label: 'মিডিয়া ক্লিনআপ',
                                  ok: setup.cleanupEnabled),
                              if (setup.lastCleanupAt != null)
                                Text('শেষ ক্লিনআপ ${setup.lastCleanupAt}',
                                    style: const TextStyle(
                                        color: AppColors.muted, fontSize: 12)),
                            ])),
                  ],
                ])));
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.label, required this.ok});
  final String label;
  final bool ok;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(
            ok
                ? Icons.check_circle_outline_rounded
                : Icons.radio_button_unchecked,
            size: 18,
            color: ok ? AppColors.ok : AppColors.muted),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
      ]));
}
