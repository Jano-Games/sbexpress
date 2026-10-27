import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/finance_snapshot.dart';
import '../../data/models/flight.dart';
import '../../data/models/flyer.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../data/money_payload.dart';
import '../../data/repositories/flight_repository.dart' show FlyerPaid;
import '../../widgets/account_picker.dart';
import '../../widgets/flight_parts.dart' show FieldLabel;
import '../../widgets/flow_parts.dart';
import '../../widgets/money_confirm.dart';
import '../../widgets/team_parts.dart' show FooterActions;
import '../../widgets/ui.dart';
import '../admin/money_format.dart';
import '../flyers/flyer_form_screen.dart';

class FlightFormScreen extends StatefulWidget {
  const FlightFormScreen({super.key});

  @override
  State<FlightFormScreen> createState() => _FlightFormScreenState();
}

class _FlightFormScreenState extends State<FlightFormScreen> {
  final _code = TextEditingController();
  final _cost = TextEditingController();

  /// Each picked flyer's part of the ticket when the flyers pay part.
  final _parts = <String, TextEditingController>{};

  /// What each picked flyer has already paid toward their part.
  final _paid = <String, TextEditingController>{};

  /// The account the flyers' money went into.
  String? _received;
  var _flyersPay = false;
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

  /// Payments recorded so far while saving, out of how many.
  ({int done, int total})? _recording;

  /// The created flight when a flyer payment failed after it was saved;
  /// the form is then only closed, never sent again.
  String? _savedCode;

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
    for (final field in [..._parts.values, ..._paid.values]) {
      field.dispose();
    }
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

  void _pick(String name) {
    _picked.add(name);
    _parts.putIfAbsent(name, TextEditingController.new);
    _paid.putIfAbsent(name, TextEditingController.new);
  }

  /// Opens the new flyer form, then picks the flyer it made.
  Future<void> _addFlyer() async {
    final name = await Navigator.of(context).push<String>(MaterialPageRoute(
        builder: (_) => const FlyerFormScreen(returnName: true)));
    if (name == null || !mounted) return;
    setState(() => _loading = true);
    await _load();
    if (!mounted) return;
    setState(() => _pick(name));
  }

  double _typedPaid(String name) =>
      _flyersPay ? (readOptionalMoney(_paid[name]?.text ?? '') ?? 0) : 0;

  bool get _anyPaid => _picked.any((name) => _typedPaid(name) > 0);

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
    if (_savedCode != null) {
      Navigator.of(context).pop(true);
      return;
    }
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
    if (actual == null) {
      setState(() => _error =
          tr('Enter the ticket cost as a number with up to two decimals.'));
      return;
    }
    final names = _picked.toList();
    final parts = <String, double>{};
    for (final name in names) {
      final part =
          _flyersPay ? readOptionalMoney(_parts[name]?.text ?? '') : 0.0;
      if (part == null) {
        setState(() => _error = tr('Enter 0 or more for each flyer.'));
        return;
      }
      parts[name] = part;
    }
    final flyersTotal =
        roundMoney(parts.values.fold(0.0, (total, part) => total + part));
    if (flyersTotal > actual + 0.001) {
      setState(() =>
          _error = tr("The flyers' parts add up to more than the ticket."));
      return;
    }
    // What the flyers already paid, recorded once the flight is saved.
    final payments = <FlyerPaid>[];
    for (final name in names) {
      if (!_flyersPay) break;
      final paid = readOptionalMoney(_paid[name]?.text ?? '');
      if (paid == null) {
        setState(() => _error = tr('Enter 0 or more for each flyer.'));
        return;
      }
      if (paid > parts[name]! + 0.001) {
        setState(() => _error = tr('{name} can pay at most {amount} now.',
            {'name': name, 'amount': formatBdt(parts[name]!)}));
        return;
      }
      if (paid > 0) payments.add((name: name, amount: paid));
    }
    FinanceAccount? into;
    for (final account in _accounts) {
      if (account.name == _received) into = account;
    }
    if (payments.isNotEmpty && into == null) {
      setState(() => _error = tr('Choose the account the flyers paid into.'));
      return;
    }
    final agency = roundMoney(actual - flyersTotal);
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
    if (into != null && payments.isNotEmpty) {
      final ok = await confirmMoney(context,
          title: tr('Flyer payments'),
          body: flyerPaymentsEffect(payments,
              accountName: into.name, accountCurrency: into.currency));
      if (!ok || !mounted) return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final flights = AppScope.of(context).flights;
      final created = await flights.create(FlightDraft(
        airlineCode: code,
        date: _iso(date),
        flyerNames: names,
        spaceKg: int.tryParse(_space.text.trim()) ?? 44,
        mobiles: int.tryParse(_mobiles.text.trim()) ?? 2,
        laptops: int.tryParse(_laptops.text.trim()) ?? 1,
        actualCost: actual,
        agencyShare: agency,
        accountName: actual > 0 ? paying?.name : null,
      ));
      // One flyer gets the whole flyers' part from the server; more than one
      // need their parts saved.
      if (names.length > 1 && flyersTotal > 0) {
        await flights.allocateContributions(created, [
          for (final name in names)
            (name: name, contribution: parts[name]!, legacyPaid: 0.0),
        ]);
      }
      if (into != null && payments.isNotEmpty) {
        if (mounted) {
          setState(() => _recording = (done: 0, total: payments.length));
        }
        final failed = await flights.recordFlyerPayments(created, payments,
            accountName: into.name, onProgress: (done) {
          if (mounted) {
            setState(() => _recording = (done: done, total: payments.length));
          }
        });
        if (failed.isNotEmpty) {
          if (!mounted) return;
          // The flight stays saved; what failed is recorded on the flight.
          setState(() {
            _savedCode = created;
            _error = [
              trn(
                  failed.length,
                  'The flight is saved, but this payment was not recorded: {list}. Record it later in Ticket and flyers.',
                  'The flight is saved, but these payments were not recorded: {list}. Record them later in Ticket and flyers.',
                  {'list': flyerPaymentsList(failed.map((f) => f.row))}),
              failed.first.reason,
            ].join('\n');
          });
          return;
        }
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _recording = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = _date == null ? tr('Choose date') : _iso(_date!);
    return WorkspaceScaffold(
        title: tr('New flight'),
        root: false,
        // Save problems show by the button, where the eye is.
        footer: FooterActions(
            error: _error,
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_recording case final progress?)
                    RecordingProgress(
                        done: progress.done, total: progress.total),
                  AppButton(
                      key: const Key('flight-save'),
                      label:
                          _savedCode == null ? tr('Save flight') : tr('Close'),
                      kind: AppButtonKind.current,
                      busy: _busy,
                      onPressed: _save),
                ])),
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
              subtitle: tr('Who will fly on this ticket.'),
              action: _flyers.isEmpty
                  ? null
                  : TextButton.icon(
                      key: const Key('flight-new-flyer'),
                      onPressed: _busy ? null : _addFlyer,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text(tr('Add flyer')))),
          if (_flyers.isEmpty && !_loading) ...[
            EmptyNote(
                icon: Icons.person_outline_rounded,
                title: tr('No flyers'),
                body: tr('Create a flyer profile first.')),
            const SizedBox(height: 10),
            AppButton(
                key: const Key('flight-add-flyer'),
                label: tr('Add flyer'),
                icon: Icons.person_add_alt_1_rounded,
                kind: AppButtonKind.tonal,
                onPressed: _busy ? null : _addFlyer),
            const SizedBox(height: 12),
          ],
          for (final flyer in _flyers)
            CheckboxListTile(
              value: _picked.contains(flyer.name),
              onChanged: (value) => setState(() {
                if (value == true) {
                  _pick(flyer.name);
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
          const SizedBox(height: 16),
          SectionTitle(title: tr('Who pays the ticket?')),
          ChoicePair(
              first: BigChoice(
                  key: const Key('flight-we-pay'),
                  icon: Icons.apartment_rounded,
                  title: tr('We pay all'),
                  subtitle: tr('Our company pays the whole ticket'),
                  selected: !_flyersPay,
                  onTap: () => setState(() => _flyersPay = false)),
              second: BigChoice(
                  key: const Key('flight-flyers-pay'),
                  icon: Icons.groups_2_outlined,
                  title: tr('Flyers pay part'),
                  subtitle: tr('Each flyer pays a part, we pay the rest'),
                  selected: _flyersPay,
                  onTap: () => setState(() => _flyersPay = true))),
          if (_flyersPay) ...[
            const SizedBox(height: 12),
            if (_picked.isEmpty)
              Text(tr('Choose the flyers above first.'),
                  style: const TextStyle(color: AppColors.muted, height: 1.45))
            else ...[
              for (final name in _picked)
                Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: FlyerPartRow(
                        name: name,
                        part: _parts[name]!,
                        paid: _paid[name],
                        paidLabel: tr('Already paid'),
                        payable: () =>
                            readOptionalMoney(_parts[name]!.text) ?? 0,
                        partKey: ValueKey('flight-part-$name'),
                        paidKey: ValueKey('flight-paid-$name'),
                        onChanged: (_) => setState(() {}))),
              if (_anyPaid) ...[
                const SizedBox(height: 4),
                FieldLabel(tr('Received in')),
                AccountPicker(
                    key: const Key('flight-received-in'),
                    accounts: _accounts,
                    selected: _received,
                    onSelected: (account) =>
                        setState(() => _received = account.name)),
              ],
            ],
          ],
          const SizedBox(height: 8),
          Builder(builder: (context) {
            final cost = readOptionalMoney(_cost.text) ?? 0;
            final flyers = _flyersPay
                ? roundMoney(_picked.fold(
                    0.0,
                    (total, name) =>
                        total +
                        (readOptionalMoney(_parts[name]?.text ?? '') ?? 0)))
                : 0.0;
            final ours = roundMoney(cost - flyers);
            if (cost <= 0) return const SizedBox.shrink();
            return SplitSummary(
                ours: ours < 0 ? 0 : ours,
                flyers: flyers,
                ticket: cost,
                problem: ours < -0.001
                    ? tr("The flyers' parts add up to more than the ticket.")
                    : null);
          }),
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
        ]);
  }
}

String _iso(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
