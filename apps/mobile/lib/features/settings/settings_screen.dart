import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/flow.dart';
import '../../data/models/workspace.dart';
import '../../data/money_payload.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/flow_parts.dart' show usualCostIcon, usualCostLabel;
import '../../widgets/team_parts.dart';
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

  /// Null until the first load; then open while a setup check is missing.
  bool? _setupOpen;
  final _rate = TextEditingController();

  /// Usual shipment cost amounts, edited in place.
  var _costsOpen = false;
  final _costFields = {
    for (final key in usualCostKeys) key: TextEditingController()
  };

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
    for (final field in _costFields.values) {
      field.dispose();
    }
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
        _setupOpen ??= _checks(setup).any((check) => !check.ok);
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
      setState(() => _error =
          tr('Enter the real CNY rate. Blank or 0 will not be saved.'));
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

  void _editCosts(CostDefaults defaults) {
    for (final key in usualCostKeys) {
      final value = defaults.of(key);
      _costFields[key]!.text = value > 0 ? plainNumber(value) : '';
    }
    setState(() {
      _costsOpen = true;
      _error = null;
    });
  }

  Future<void> _saveCosts() async {
    var defaults = const CostDefaults();
    for (final key in usualCostKeys) {
      final value = readOptionalMoney(_costFields[key]!.text);
      if (value == null) {
        setState(() => _error = tr(
            'Enter each usual cost as a number, or leave it empty for none.'));
        return;
      }
      defaults = defaults.withValue(key, value);
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.of(context).settings.saveCostDefaults(defaults);
      if (!mounted) return;
      setState(() => _costsOpen = false);
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

  Future<void> _newMethod() async {
    final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const PayMethodFormScreen()));
    if (saved == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final setup = _setup;
    final settings = _settings;
    return WorkspaceScaffold(
        title: tr('Settings'),
        subtitle: tr('Payments, exchange rate and your team'),
        root: false,
        onRefresh: _load,
        children: [
          if (_loading && setup == null) const LinearProgressIndicator(),
          if (_error != null) ErrorNote(message: _error!, onRetry: _load),
          if (setup != null && settings != null) ...[
            _rateCard(setup, settings),
            if (settings.costDefaults != null) ...[
              const SizedBox(height: 14),
              _costsCard(settings.costDefaults!),
            ],
            const SizedBox(height: 22),
            SectionTitle(
                title: tr('Payment methods'),
                subtitle: tr('Shown on the customer link'),
                action: BarPillButton(label: tr('New'), onPressed: _newMethod)),
            if (_methods.isEmpty)
              EmptyNote(
                  icon: Icons.account_balance_wallet_outlined,
                  title: tr('No methods'),
                  body: tr('Add bKash, bank or wallet details.'))
            else
              SurfaceGroup(children: [
                for (final method in _methods)
                  _MethodRow(
                      method: method,
                      onChanged: _busy ? null : (_) => _toggle(method)),
              ]),
            const SizedBox(height: 22),
            SectionTitle(title: tr('Team and operations')),
            SurfaceGroup(children: [
              MenuRow(
                  title: tr('Staff management'),
                  subtitle: tr('{count} active · Access and passwords', {
                    'count': _staff.where((person) => person.active).length
                  }),
                  icon: Icons.people_outline_rounded,
                  onTap: _openStaff),
              Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(children: [
                    const IconBadge(Icons.balance_rounded,
                        tone: ChipTone.neutral),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(tr('Weight alert'),
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600)),
                          Text(tr('Booked vs weighed difference'),
                              style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.4,
                                  color: AppColors.muted)),
                        ])),
                    const SizedBox(width: 8),
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: AppColors.neutralSoft,
                            borderRadius: BorderRadius.circular(999)),
                        child: Text('${plainNumber(settings.threshold)} kg',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.inkSoft))),
                  ])),
            ]),
            const SizedBox(height: 22),
            _setupCard(setup),
          ],
        ]);
  }

  Widget _rateCard(SetupStatus setup, SettingsSnapshot settings) => PaperCard(
      radius: heroRadius,
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const IconBadge(Icons.swap_horiz_rounded, size: 44),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(tr('Exchange rate'),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted)),
                FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text('1 CNY = ${formatBdt(settings.rate)}',
                        maxLines: 1,
                        style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                            fontFeatures: [FontFeature.tabularFigures()]))),
              ])),
          const SizedBox(width: 8),
          setup.rateConfirmed
              ? StatusPill(label: tr('Confirmed'), tone: ChipTone.green)
              : StatusPill(label: tr('Not confirmed'), tone: ChipTone.amber),
        ]),
        const SizedBox(height: 8),
        Text(tr('New transactions use this rate.'),
            style: const TextStyle(fontSize: 13, color: AppColors.muted)),
        const SizedBox(height: 14),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
              child: LabeledField(
                  label: tr('BDT per CNY'),
                  child: TextField(
                      controller: _rate,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                          prefixIcon: fieldSign('৳'),
                          prefixIconConstraints: fieldSignConstraints)))),
          const SizedBox(width: 10),
          Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: AppButton(
                  label: tr('Save rate'),
                  expand: false,
                  busy: _busy,
                  onPressed: _saveRate)),
        ]),
      ]));

  Widget _costsCard(CostDefaults defaults) => PaperCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const IconBadge(Icons.inventory_2_outlined),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(tr('Usual shipment costs'),
                    style: const TextStyle(
                        fontSize: 15,
                        height: 1.35,
                        fontWeight: FontWeight.w700)),
                Text(tr('Filled in when one is added to a shipment'),
                    style: const TextStyle(
                        fontSize: 13, height: 1.4, color: AppColors.muted)),
              ])),
          if (!_costsOpen)
            TextButton(
                key: const Key('costs-edit'),
                onPressed: () => _editCosts(defaults),
                child: Text(tr('Edit'))),
        ]),
        const SizedBox(height: 12),
        if (_costsOpen) ...[
          for (var i = 0; i < usualCostKeys.length; i += 2) ...[
            if (i > 0) const SizedBox(height: 12),
            PairRow(
                first: _costField(usualCostKeys[i]),
                second: _costField(usualCostKeys[i + 1])),
          ],
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
                child: AppButton(
                    label: tr('Cancel'),
                    kind: AppButtonKind.quiet,
                    onPressed: _busy
                        ? null
                        : () => setState(() => _costsOpen = false))),
            const SizedBox(width: 10),
            Expanded(
                child: AppButton(
                    key: const Key('costs-save'),
                    label: tr('Save'),
                    busy: _busy,
                    onPressed: _saveCosts)),
          ]),
        ] else
          for (var i = 0; i < usualCostKeys.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.lineSoft),
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(children: [
                  Icon(usualCostIcon(usualCostKeys[i]),
                      size: 18, color: AppColors.inkSoft),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(usualCostLabel(usualCostKeys[i]),
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600))),
                  Text(
                      defaults.of(usualCostKeys[i]) > 0
                          ? formatBdt(defaults.of(usualCostKeys[i]))
                          : tr('Not set'),
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: defaults.of(usualCostKeys[i]) > 0
                              ? AppColors.ink
                              : AppColors.muted,
                          fontFeatures: const [FontFeature.tabularFigures()])),
                ])),
          ],
      ]));

  Widget _costField(String key) => LabeledField(
      label: usualCostLabel(key),
      child: TextField(
          key: ValueKey('costs-$key'),
          controller: _costFields[key],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
              hintText: '0',
              prefixIcon: fieldSign('৳'),
              prefixIconConstraints: fieldSignConstraints)));

  List<({String label, String value, bool ok})> _checks(SetupStatus setup) => [
        (
          label: tr('CNY rate'),
          value: setup.rateConfirmed ? tr('Confirmed') : tr('Not confirmed'),
          ok: setup.rateConfirmed
        ),
        (
          label: tr('Fund accounts'),
          value: '${setup.accounts}',
          ok: setup.accounts > 0
        ),
        (
          label: tr('Payment methods'),
          value: '${setup.paymentMethods}',
          ok: setup.paymentMethods > 0
        ),
        (
          label: tr('Active staff'),
          value: '${setup.users}',
          ok: setup.users > 0
        ),
        (
          label: tr('Storage'),
          value: setup.storageConfigured ? tr('Set up') : tr('Not set up'),
          ok: setup.storageConfigured
        ),
        (
          label: tr('Media cleanup'),
          value: setup.cleanupEnabled ? tr('On') : tr('Off'),
          ok: setup.cleanupEnabled
        ),
      ];

  Widget _setupCard(SetupStatus setup) {
    final checks = _checks(setup);
    final done = checks.where((check) => check.ok).length;
    final open = _setupOpen ?? false;
    return PaperCard(
        padding: EdgeInsets.zero,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Semantics(
              expanded: open,
              button: true,
              child: InkWell(
                  onTap: () => setState(() => _setupOpen = !open),
                  child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        const IconBadge(Icons.fact_check_outlined,
                            tone: ChipTone.neutral),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(tr('System setup'),
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600)),
                              Text(tr('Connections and required settings'),
                                  style: const TextStyle(
                                      fontSize: 13,
                                      height: 1.4,
                                      color: AppColors.muted)),
                            ])),
                        const SizedBox(width: 8),
                        StatusPill(
                            label: '$done / ${checks.length}',
                            tone: done == checks.length
                                ? ChipTone.green
                                : ChipTone.neutral),
                        const SizedBox(width: 4),
                        Icon(
                            open
                                ? Icons.expand_less_rounded
                                : Icons.expand_more_rounded,
                            size: 22,
                            color: AppColors.muted),
                      ])))),
          if (open)
            Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ExcludeSemantics(
                          child: StepBars(
                              done: done,
                              total: checks.length,
                              current: false,
                              height: 6)),
                      const SizedBox(height: 12),
                      for (var i = 0; i < checks.length; i += 2) ...[
                        if (i > 0) const SizedBox(height: 8),
                        IntrinsicHeight(
                            child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                              Expanded(child: _CheckTile(check: checks[i])),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: i + 1 < checks.length
                                      ? _CheckTile(check: checks[i + 1])
                                      : const SizedBox.shrink()),
                            ])),
                      ],
                      if (setup.lastCleanupAt != null) ...[
                        const SizedBox(height: 10),
                        Text(
                            tr('Last cleanup {at}',
                                {'at': setup.lastCleanupAt}),
                            style: const TextStyle(
                                color: AppColors.muted, fontSize: 12)),
                      ],
                    ])),
        ]));
  }
}

class _MethodRow extends StatelessWidget {
  const _MethodRow({required this.method, required this.onChanged});
  final PayMethodInfo method;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final bank = method.kind == 'bank_account';
    final detail = [
      method.currency,
      bank
          ? tr('bank account')
          : method.number.isEmpty
              ? method.provider
              : method.number,
      if (!method.enabled) tr('hidden'),
    ].join(' · ');
    return Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(children: [
          IconBadge(
              bank ? Icons.account_balance_outlined : Icons.smartphone_rounded,
              tone: method.enabled ? ChipTone.blue : ChipTone.neutral),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(method.title,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: method.enabled
                            ? AppColors.ink
                            : AppColors.inkSoft)),
                Text(detail,
                    style: const TextStyle(
                        fontSize: 13, height: 1.4, color: AppColors.muted)),
              ])),
          const SizedBox(width: 8),
          Semantics(
              label: method.title,
              child: Switch(value: method.enabled, onChanged: onChanged)),
        ]));
  }
}

class _CheckTile extends StatelessWidget {
  const _CheckTile({required this.check});
  final ({String label, String value, bool ok}) check;

  @override
  Widget build(BuildContext context) {
    final body = Padding(
        padding: const EdgeInsets.all(10),
        child: Row(children: [
          Icon(
              check.ok
                  ? Icons.check_circle_outline_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 18,
              color: check.ok ? AppColors.ok : AppColors.muted),
          const SizedBox(width: 8),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                Text(check.label,
                    style: const TextStyle(
                        fontSize: 12, height: 1.35, color: AppColors.muted)),
                Text(check.value,
                    style: TextStyle(
                        fontSize: 14,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: check.ok ? AppColors.ink : AppColors.muted)),
              ])),
        ]));
    return check.ok
        ? DecoratedBox(
            decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(controlRadius)),
            child: body)
        : DashedOutline(
            color: AppColors.field,
            strokeWidth: 1,
            background: AppColors.card,
            child: body);
  }
}
