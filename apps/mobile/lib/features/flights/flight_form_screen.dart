import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/finance_snapshot.dart';
import '../../data/models/flight.dart';
import '../../data/models/flyer.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../data/money_payload.dart';
import '../../widgets/account_picker.dart';
import '../../widgets/money_confirm.dart';
import '../../widgets/ui.dart';
import '../admin/money_format.dart';

class FlightFormScreen extends StatefulWidget {
  const FlightFormScreen({super.key});

  @override
  State<FlightFormScreen> createState() => _FlightFormScreenState();
}

class _FlightFormScreenState extends State<FlightFormScreen> {
  final _code = TextEditingController();
  final _cost = TextEditingController();
  final _agency = TextEditingController();
  final _space = TextEditingController(text: '44');
  final _mobiles = TextEditingController(text: '2');
  final _laptops = TextEditingController(text: '1');
  DateTime? _date;
  List<FlyerSummary> _flyers = const [];
  List<FinanceAccount> _accounts = const [];
  String? _account;
  final _picked = <String>{};
  String? _error;
  var _loading = true;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _code.dispose();
    _cost.dispose();
    _agency.dispose();
    _space.dispose();
    _mobiles.dispose();
    _laptops.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final scope = AppScope.of(context);
      final flyers = await scope.flyers.list();
      final finance = await scope.finance.snapshot();
      if (!mounted) return;
      setState(() {
        _flyers = flyers;
        _accounts = finance.accounts;
      });
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final code = _code.text.trim().toUpperCase();
    final date = _date;
    if (code.length < 2) {
      setState(() => _error = tr('Enter the airline flight number.'));
      return;
    }
    if (date == null) {
      setState(() => _error = tr('Choose a date.'));
      return;
    }
    if (_picked.isEmpty) {
      setState(() => _error = tr('Choose at least one flyer.'));
      return;
    }
    final actual = readOptionalMoney(_cost.text);
    final agency = readOptionalMoney(_agency.text);
    if (actual == null || agency == null || agency > actual) {
      setState(() => _error = tr(
          'Ticket cost and agency share must be 0 or more, with up to two decimals. Blank counts as 0. Agency share cannot exceed the actual cost.'));
      return;
    }
    FinanceAccount? paying;
    for (final account in _accounts) {
      if (account.name == _account) paying = account;
    }
    if (actual > 0 && paying != null) {
      final chosen = paying;
      final ok = await confirmMoney(
        context,
        title: tr('Ticket payment'),
        body: bdtFundMovement(
            amountBdt: actual,
            accountName: chosen.name,
            accountCurrency: chosen.currency,
            intoAccount: false),
      );
      if (!ok || !mounted) return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.of(context).flights.create(FlightDraft(
            airlineCode: code,
            date: _iso(date),
            flyerNames: _picked.toList(),
            spaceKg: int.tryParse(_space.text.trim()) ?? 44,
            mobiles: int.tryParse(_mobiles.text.trim()) ?? 2,
            laptops: int.tryParse(_laptops.text.trim()) ?? 1,
            actualCost: actual,
            agencyShare: agency,
            accountName: actual > 0 ? paying?.name : null,
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
    final dateLabel = _date == null ? tr('Choose date') : _iso(_date!);
    return WorkspaceScaffold(
        title: tr('New flight'),
        root: false,
        footer: ActionFooter(
            child: AppButton(
                label: tr('Save flight'),
                kind: AppButtonKind.current,
                busy: _busy,
                onPressed: _save)),
        children: [
          Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                  tr(
                      'Flight numbers repeat every day; the server creates the booking reference. Nothing is deducted unless you pay. If you choose an account, the ticket money is paid from it.'),
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.muted, height: 1.5))),
          if (_loading)
            const LinearProgressIndicator(
                color: AppColors.teal, backgroundColor: AppColors.tealSoft),
          TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              decoration:
                  InputDecoration(labelText: tr('Airline flight number'))),
          const SizedBox(height: 12),
          AppButton(
              label: dateLabel,
              kind: AppButtonKind.quiet,
              onPressed: _pickDate),
          const SizedBox(height: 16),
          SectionTitle(
              title: tr('Flyers'),
              subtitle: tr('Who will fly on this ticket.')),
          if (_flyers.isEmpty && !_loading)
            EmptyNote(
                title: tr('No flyers'),
                body: tr('Create a flyer profile first.')),
          for (final flyer in _flyers)
            CheckboxListTile(
              value: _picked.contains(flyer.name),
              onChanged: (value) => setState(() {
                if (value == true) {
                  _picked.add(flyer.name);
                } else {
                  _picked.remove(flyer.name);
                }
              }),
              contentPadding: EdgeInsets.zero,
              title: Text(flyer.name),
              subtitle: Text(flyer.bdPhone),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          const SizedBox(height: 8),
          TextField(
              controller: _space,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText: tr('Capacity kg'),
                  helperText: tr('Usually 44 or 52'))),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                  child: TextField(
                      controller: _mobiles,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: tr('Mobiles')))),
              const SizedBox(width: 8),
              Expanded(
                  child: TextField(
                      controller: _laptops,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: tr('Laptops')))),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _cost,
            onChanged: (_) => setState(() {}),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
                labelText: tr('Actual ticket cost (BDT)'),
                helperText: tr('Leave blank if unknown')),
          ),
          const SizedBox(height: 8),
          TextField(
              controller: _agency,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: tr('Agency share (BDT)'))),
          if ((double.tryParse(_cost.text.trim()) ?? 0) > 0) ...[
            const SizedBox(height: 12),
            SectionTitle(
                title: tr('Pay from account'),
                subtitle: tr(
                    'If none is chosen, no cash moves now. You can settle it from the flight later.')),
            AccountPicker(
                accounts: _accounts,
                selected: _account,
                onSelected: (account) =>
                    setState(() => _account = account.name)),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: AppColors.danger, height: 1.35)),
          ],
        ]);
  }
}

String _iso(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
