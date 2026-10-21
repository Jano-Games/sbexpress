import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/finance_snapshot.dart';
import '../../data/models/flight.dart';
import '../../data/money_payload.dart';
import '../../theme/app_colors.dart';
import '../../widgets/account_picker.dart';
import '../../widgets/money_confirm.dart';
import '../../widgets/ui.dart';
import '../admin/money_format.dart';

class FlightMoneyScreen extends StatefulWidget {
  const FlightMoneyScreen({super.key, required this.code});

  final String code;

  @override
  State<FlightMoneyScreen> createState() => _FlightMoneyScreenState();
}

class _FlightMoneyScreenState extends State<FlightMoneyScreen> {
  FlightDetail? _detail;
  String? _error;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await AppScope.of(context).flights.detail(widget.code);
      if (!mounted) return;
      setState(() => _detail = detail);
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

  Future<void> _open(Widget screen) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => screen));
    if (saved == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final summary = _detail?.summary;
    return Scaffold(
      appBar: BackTitle(title: summary?.displayCode ?? displayFlightCode(widget.code)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(pageGutter, 8, pageGutter, 32),
        children: [
          const PageHeader(title: 'টিকিটের টাকা', subtitle: 'আগে কনট্রিবিউশন ভাগ করুন, তারপর ফ্লায়ারের জমা। টিকিট ক্যাশ আলাদা।'),
          if (_loading && summary == null) const LinearProgressIndicator(color: AppColors.teal, backgroundColor: AppColors.tealSoft),
          if (_error != null) ...[
            ErrorNote(message: _error!, onRetry: _load),
            const SizedBox(height: 12),
          ],
          if (summary != null) ...[
            PaperCard(
              child: Column(
                children: [
                  KvRow(label: 'আসল খরচ', value: formatBdt(summary.actualCost)),
                  KvRow(label: 'এজেন্সি', value: formatBdt(summary.agencyShare)),
                  KvRow(label: 'ফ্লায়ার বাকি', value: formatBdt(summary.flyerDue)),
                  KvRow(label: 'টিকিট বাকি', value: formatBdt(summary.ticketDue), valueColor: summary.ticketDue > 0 ? AppColors.danger : AppColors.ok),
                  KvRow(label: 'টিকিট রিফান্ড', value: formatBdt(summary.ticketRefundDue)),
                  if (summary.unallocatedFlyerPaid > 0) KvRow(label: 'অবণ্টিত জমা', value: formatBdt(summary.unallocatedFlyerPaid)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppButton(label: 'টিকিট ক্যাশ সেটল', kind: AppButtonKind.current, onPressed: () => _open(TicketSettleScreen(code: widget.code))),
            const SizedBox(height: 8),
            AppButton(label: 'কনট্রিবিউশন ভাগ', kind: AppButtonKind.teal, onPressed: () => _open(ContributionScreen(code: widget.code))),
            const SizedBox(height: 8),
            AppButton(label: 'ফ্লায়ার জমা', kind: AppButtonKind.teal, onPressed: () => _open(FlyerPaymentScreen(code: widget.code))),
          ],
        ],
      ),
    );
  }
}

class TicketSettleScreen extends StatefulWidget {
  const TicketSettleScreen({super.key, required this.code});

  final String code;

  @override
  State<TicketSettleScreen> createState() => _TicketSettleScreenState();
}

class _TicketSettleScreenState extends State<TicketSettleScreen> {
  FlightSummary? _summary;
  List<FinanceAccount> _accounts = const [];
  String? _account;
  String? _error;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final scope = AppScope.of(context);
      final detail = await scope.flights.detail(widget.code);
      final finance = await scope.finance.snapshot();
      if (!mounted) return;
      setState(() {
        _summary = detail.summary;
        _accounts = finance.accounts;
      });
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    }
  }

  Future<void> _save() async {
    final summary = _summary;
    FinanceAccount? account;
    for (final row in _accounts) {
      if (row.name == _account) account = row;
    }
    if (summary == null || account == null) {
      setState(() => _error = 'অ্যাকাউন্ট বেছে নিন।');
      return;
    }
    final chosen = account;
    if (summary.ticketDue <= 0 && summary.ticketRefundDue <= 0) {
      setState(() => _error = 'টিকিটে সেটল করার মতো বাকি বা রিফান্ড নেই।');
      return;
    }
    final effect = summary.ticketDue > 0
        ? 'বাকি ${formatBdt(summary.ticketDue)} ${chosen.name} থেকে কাটা হবে।'
        : 'রিফান্ড ${formatBdt(summary.ticketRefundDue)} ${chosen.name}-এ ফিরবে।';
    final ok = await confirmMoney(context, title: 'টিকিট সেটল', body: effect);
    if (!ok || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.of(context).flights.settleTicket(widget.code, chosen.name);
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
    final summary = _summary;
    return Scaffold(
      appBar: const BackTitle(title: 'টিকিট ক্যাশ'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(pageGutter, 8, pageGutter, 32),
        children: [
          const PageHeader(title: 'টিকিট ক্যাশ', subtitle: 'শুধু বাকি টিকিট খরচ বা রিফান্ড এই অ্যাকাউন্টে বসবে। অন্য ফিল্ড বদলায় না।'),
          if (summary != null) ...[
            KvRow(label: 'বাকি', value: formatBdt(summary.ticketDue)),
            KvRow(label: 'রিফান্ড', value: formatBdt(summary.ticketRefundDue)),
          ],
          const SizedBox(height: 12),
          AccountPicker(accounts: _accounts, selected: _account, onSelected: (account) => setState(() => _account = account.name)),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.danger, height: 1.35)),
          ],
          const SizedBox(height: 16),
          AppButton(label: 'সেটল করুন', kind: AppButtonKind.current, busy: _busy, onPressed: _save),
        ],
      ),
    );
  }
}

class ContributionScreen extends StatefulWidget {
  const ContributionScreen({super.key, required this.code});

  final String code;

  @override
  State<ContributionScreen> createState() => _ContributionScreenState();
}

class _ContributionScreenState extends State<ContributionScreen> {
  FlightSummary? _summary;
  final _contribution = <String, TextEditingController>{};
  final _legacy = <String, TextEditingController>{};
  String? _error;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    for (final controller in _contribution.values) {
      controller.dispose();
    }
    for (final controller in _legacy.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final detail = await AppScope.of(context).flights.detail(widget.code);
      if (!mounted) return;
      final summary = detail.summary;
      for (final name in summary.flyers) {
        FlightSettlement? settlement;
        for (final row in summary.settlements) {
          if (row.name == name) settlement = row;
        }
        _contribution[name] = TextEditingController(text: settlement == null ? '' : settlement.contribution.toString());
        _legacy[name] = TextEditingController();
      }
      setState(() => _summary = summary);
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    }
  }

  Future<void> _save() async {
    final summary = _summary;
    if (summary == null || summary.flyers.isEmpty) return;
    final target = roundMoney(summary.actualCost - summary.agencyShare);
    final rows = <({String name, double contribution, double legacyPaid})>[];
    var contributionSum = 0.0;
    var legacySum = 0.0;
    for (final name in summary.flyers) {
      final contribution = parseMoney(_contribution[name]?.text ?? '');
      final legacy = summary.unallocatedFlyerPaid <= 0 ? 0.0 : (_legacy[name]!.text.trim().isEmpty ? 0.0 : parseMoney(_legacy[name]!.text));
      if (contribution == null || contribution < 0 || legacy == null || legacy < 0) {
        setState(() => _error = 'প্রতিটি ফ্লায়ারের অঙ্ক ০ বা তার বেশি দিন।');
        return;
      }
      contributionSum += contribution;
      legacySum += legacy;
      rows.add((name: name, contribution: contribution, legacyPaid: legacy));
    }
    if ((roundMoney(contributionSum) - target).abs() > 0.001) {
      setState(() => _error = 'কনট্রিবিউশন মিলিয়ে ${formatBdt(target)} হতে হবে।');
      return;
    }
    if ((roundMoney(legacySum) - summary.unallocatedFlyerPaid).abs() > 0.001) {
      setState(() => _error = 'আগের অবণ্টিত জমা ${formatBdt(summary.unallocatedFlyerPaid)} ঠিক একবার ভাগ করুন।');
      return;
    }
    final ok = await confirmMoney(context, title: 'কনট্রিবিউশন', body: 'ফ্লায়ার ভাগ ${formatBdt(target)} লক হবে। পরে জমা এই ভাগের বেশি হতে পারবে না।');
    if (!ok || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.of(context).flights.allocateContributions(widget.code, rows);
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
    final summary = _summary;
    final target = summary == null ? 0.0 : roundMoney(summary.actualCost - summary.agencyShare);
    return Scaffold(
      appBar: const BackTitle(title: 'কনট্রিবিউশন'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(pageGutter, 8, pageGutter, 32),
        children: [
          PageHeader(title: 'কনট্রিবিউশন', subtitle: 'সবার ভাগ মিলিয়ে ${formatBdt(target)}। প্রতিটি ফ্লায়ার একবার।'),
          if (summary == null)
            const LinearProgressIndicator(color: AppColors.teal, backgroundColor: AppColors.tealSoft)
          else if (summary.flyers.isEmpty)
            const EmptyNote(title: 'ফ্লায়ার নেই', body: 'আগে ফ্লাইটে ফ্লায়ার যোগ করুন।')
          else
            for (final name in summary.flyers) ...[
              Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              TextField(
                controller: _contribution[name],
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'কনট্রিবিউশন'),
              ),
              if (summary.unallocatedFlyerPaid > 0) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _legacy[name],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'আগের জমা', helperText: 'মোট ${formatBdt(summary.unallocatedFlyerPaid)}'),
                ),
              ],
              const SizedBox(height: 12),
            ],
          if (_error != null) Text(_error!, style: const TextStyle(color: AppColors.danger, height: 1.35)),
          const SizedBox(height: 8),
          AppButton(label: 'ভাগ সেভ', kind: AppButtonKind.current, busy: _busy, onPressed: summary == null || summary.flyers.isEmpty ? null : _save),
        ],
      ),
    );
  }
}

class FlyerPaymentScreen extends StatefulWidget {
  const FlyerPaymentScreen({super.key, required this.code});

  final String code;

  @override
  State<FlyerPaymentScreen> createState() => _FlyerPaymentScreenState();
}

class _FlyerPaymentScreenState extends State<FlyerPaymentScreen> {
  FlightSummary? _summary;
  List<FinanceAccount> _accounts = const [];
  final _amount = TextEditingController();
  String? _flyer;
  String? _account;
  String? _error;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final scope = AppScope.of(context);
      final detail = await scope.flights.detail(widget.code);
      final finance = await scope.finance.snapshot();
      if (!mounted) return;
      setState(() {
        _summary = detail.summary;
        _accounts = finance.accounts;
      });
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    }
  }

  FlightSettlement? _settlement(String name) {
    final summary = _summary;
    if (summary == null) return null;
    for (final row in summary.settlements) {
      if (row.name == name) return row;
    }
    return null;
  }

  Future<void> _save() async {
    final name = _flyer;
    final settlement = name == null ? null : _settlement(name);
    FinanceAccount? account;
    for (final row in _accounts) {
      if (row.name == _account) account = row;
    }
    final amount = parseMoney(_amount.text);
    if (name == null || settlement == null || settlement.contribution <= 0 || account == null || amount == null || amount <= 0) {
      setState(() => _error = 'আগে ভাগ সেভ করুন, তারপর ফ্লায়ার, অ্যাকাউন্ট ও অঙ্ক দিন।');
      return;
    }
    final chosen = account;
    final due = roundMoney(settlement.contribution - settlement.paidAmount);
    if (amount > due + 0.001) {
      setState(() => _error = 'এই ফ্লায়ারের বাকি ${formatBdt(due)}-এর বেশি নয়।');
      return;
    }
    final ok = await confirmMoney(context, title: 'ফ্লায়ার জমা', body: '${formatMoney(amount, chosen.currency)} ${chosen.name}-এ $name-এর জমা হিসেবে ঢুকবে।');
    if (!ok || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.of(context).flights.recordFlyerPayment(widget.code, amount: amount, accountName: chosen.name, currency: chosen.currency, flyerName: name);
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
    final summary = _summary;
    return Scaffold(
      appBar: const BackTitle(title: 'ফ্লায়ার জমা'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(pageGutter, 8, pageGutter, 32),
        children: [
          const PageHeader(title: 'ফ্লায়ার জমা', subtitle: 'যে অ্যাকাউন্টে টাকা এসেছে এবং যে ফ্লায়ার দিয়েছেন, সেটাই লিখুন।'),
          if (summary == null)
            const LinearProgressIndicator(color: AppColors.teal, backgroundColor: AppColors.tealSoft)
          else ...[
            for (final name in summary.flyers) ...[
              _PickTile(
                title: name,
                subtitle: () {
                  final row = _settlement(name);
                  if (row == null) return 'ভাগ এখনো সেভ হয়নি';
                  return 'ভাগ ${formatBdt(row.contribution)} · পেইড ${formatBdt(row.paidAmount)}';
                }(),
                selected: _flyer == name,
                onTap: () => setState(() => _flyer = name),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 8),
            AccountPicker(accounts: _accounts, selected: _account, onSelected: (account) => setState(() => _account = account.name)),
            TextField(controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'অঙ্ক')),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.danger, height: 1.35)),
          ],
          const SizedBox(height: 16),
          AppButton(label: 'জমা সেভ', kind: AppButtonKind.current, busy: _busy, onPressed: _save),
        ],
      ),
    );
  }
}

class _PickTile extends StatelessWidget {
  const _PickTile({required this.title, required this.subtitle, required this.selected, required this.onTap});

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.tealSoft : AppColors.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: minTouchTarget),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? AppColors.teal : AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(subtitle, style: const TextStyle(color: AppColors.muted)),
            ],
          ),
        ),
      ),
    );
  }
}
