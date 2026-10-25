import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/customer.dart';
import '../../data/models/flight.dart';
import '../../data/models/workspace.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/flight_parts.dart';
import '../../widgets/ui.dart';
import '../admin/admin_shipment_screen.dart';
import '../admin/money_format.dart';
import '../customers/customer_form_screen.dart';

class IntakeScreen extends StatefulWidget {
  const IntakeScreen({super.key, this.lockedFlightCode});

  final String? lockedFlightCode;

  @override
  State<IntakeScreen> createState() => _IntakeScreenState();
}

class _IntakeScreenState extends State<IntakeScreen> {
  List<CustomerSummary> _customers = const [];
  List<FlightSummary> _flights = const [];
  List<String> _categories = const [];
  Map<String, double> _pcsRates = const {};
  String? _error;
  var _loading = true;
  var _busy = false;
  var _stage = 0;
  var _addingCategory = false;
  var _savingCategory = false;

  String? _supplier;
  final _picked = <String>{};
  final _categoryName = TextEditingController();
  final _kg = TextEditingController();
  final _rate = TextEditingController();
  final _description = TextEditingController();
  var _currency = 'BDT';
  var _terms = 'invoice';
  String? _flight;
  String? _flyer;
  final _pieces = <String, _PieceDraft>{};

  static const _currencies = ['BDT', 'CNY'];
  static const _termValues = ['invoice', 'cod', 'monthly'];

  @override
  void initState() {
    super.initState();
    _flight = widget.lockedFlightCode;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _categoryName.dispose();
    _kg.dispose();
    _rate.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final scope = AppScope.of(context);
      final customers = await scope.customers.list();
      final flights = await scope.flights.list();
      final categories = await scope.settings.categories();
      final settings = await scope.settings.current();
      if (!mounted) return;
      setState(() {
        _customers = customers;
        _flights = [
          for (final flight in flights)
            if (flight.status == 'upcoming') flight
        ];
        _categories = categories;
        _pcsRates = settings.pcsRates;
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

  FlightSummary? get _selectedFlight {
    for (final flight in _flights) {
      if (flight.code == _flight) return flight;
    }
    return null;
  }

  CustomerSummary? get _selectedCustomer {
    for (final customer in _customers) {
      if (customer.code == _supplier) return customer;
    }
    return null;
  }

  double get _kgValue => double.tryParse(_kg.text.trim()) ?? 0;
  double get _rateValue => double.tryParse(_rate.text.trim()) ?? 0;

  Future<String?> _pick(
          String title,
          List<({String value, String title, String subtitle})> options,
          String? selected) =>
      showModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) =>
              _PickerSheet(title: title, options: options, selected: selected));

  Future<void> _pickCustomer() async {
    final value = await _pick(
        tr('Choose a customer'),
        [
          for (final customer in _customers)
            (
              value: customer.code,
              title: customer.name,
              subtitle: '${customer.code} · ${customer.phone}'
            ),
        ],
        _supplier);
    if (mounted && value != null) setState(() => _supplier = value);
  }

  Future<void> _newCustomer() async {
    final created = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const CustomerFormScreen()));
    if (created == true && mounted) await _load();
  }

  void _chooseFlight(String? code) {
    setState(() {
      _flight = code;
      final flyers = _selectedFlight?.flyers ?? <String>[];
      _flyer = flyers.length == 1 ? flyers.first : null;
    });
  }

  bool _isPiece(String name) =>
      _pcsRates.containsKey(name) ||
      RegExp('mobile|laptop|drone', caseSensitive: false).hasMatch(name);

  void _toggleCategory(String name) {
    setState(() {
      if (_picked.contains(name)) {
        _picked.remove(name);
        _pieces.remove(name);
      } else {
        _picked.add(name);
        if (_isPiece(name)) {
          _pieces[name] = _PieceDraft(rate: _pcsRates[name] ?? 0);
        }
      }
    });
  }

  Future<void> _addCategory() async {
    final name = _categoryName.text.trim();
    if (name.isEmpty || _savingCategory) return;
    setState(() => _savingCategory = true);
    try {
      await AppScope.of(context).settings.addCategory(name);
      if (!mounted) return;
      _categoryName.clear();
      if (!_categories.contains(name)) _categories = [..._categories, name];
      if (!_picked.contains(name)) _toggleCategory(name);
      setState(() => _addingCategory = false);
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _savingCategory = false);
    }
  }

  Future<void> _save() async {
    final supplier = _supplier;
    if (supplier == null) {
      setState(() => _error = tr('Choose a customer.'));
      return;
    }
    if (_picked.isEmpty) {
      setState(() => _error = tr('Choose at least one category.'));
      return;
    }
    final kg = double.tryParse(_kg.text.trim()) ?? 0;
    final rate = double.tryParse(_rate.text.trim()) ?? 0;
    if (kg < 0 || rate < 0) {
      setState(() => _error = tr('Weight and rate must be 0 or more.'));
      return;
    }
    final pieces = <IntakePiece>[];
    for (final name in _picked) {
      final draft = _pieces[name];
      if (draft == null) continue;
      if (draft.count < 1) {
        setState(() =>
            _error = tr('Enter the quantity for {name}.', {'name': name}));
        return;
      }
      pieces.add(draft.toPiece(name, _currency));
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final code = await AppScope.of(context).shipments.create(IntakeDraft(
            supplierCode: supplier,
            categories: _picked.toList(),
            flightCode: _flight,
            flyerName: _flyer,
            bookedKg: kg,
            chargeRate: rate,
            chargeCurrency: _currency,
            description: _description.text.trim(),
            paymentTerms: _terms,
            pieces: pieces,
          ));
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
          builder: (_) => AdminShipmentScreen(code: code)));
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _next() {
    if (_stage == 0 && (_supplier == null || _picked.isEmpty)) {
      setState(() => _error = _supplier == null
          ? tr('Choose a customer.')
          : tr('Choose at least one category.'));
      return;
    }
    if (_stage == 1 &&
        ((double.tryParse(_kg.text.trim()) ?? 0) < 0 ||
            (double.tryParse(_rate.text.trim()) ?? 0) < 0)) {
      setState(() => _error = tr('Weight and rate must be 0 or more.'));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _stage++;
    });
  }

  void _goTo(int stage) {
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _stage = stage;
    });
  }

  @override
  Widget build(BuildContext context) {
    return WorkspaceScaffold(
        // A fresh list per step, so each step opens at its top.
        key: ValueKey('intake-step-$_stage'),
        title: tr('New shipment'),
        subtitle: _stage == 2
            ? tr('Step 3 of 3 · check and create')
            : tr('Step {step} of 3', {'step': _stage + 1}),
        toolbar: WizardSteps(
            labels: [tr('Cargo'), tr('Billing'), tr('Review')],
            current: _stage,
            onBack: _busy ? (_) {} : _goTo),
        footer:
            ActionFooter(child: LayoutBuilder(builder: (context, constraints) {
          // Icons give way to the labels on narrow screens.
          final narrow = constraints.maxWidth < 340;
          return Row(children: [
            if (_stage > 0) ...[
              Expanded(
                  flex: 11,
                  child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(48, 50),
                          padding: const EdgeInsets.symmetric(horizontal: 10)),
                      onPressed: _busy ? null : () => _goTo(_stage - 1),
                      child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (!narrow) ...[
                              const Icon(Icons.arrow_back_rounded, size: 19),
                              const SizedBox(width: 6),
                            ],
                            Flexible(
                                child: Text(tr('Previous'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis)),
                          ]))),
              const SizedBox(width: 10),
            ],
            Expanded(
                flex: 16,
                child: AppButton(
                    key: const Key('intake-next'),
                    label: switch (_stage) {
                      0 => tr('Next: Billing'),
                      1 => tr('Next: Review'),
                      _ => tr('Create shipment'),
                    },
                    icon: _stage == 2 && !narrow ? Icons.check_rounded : null,
                    busy: _busy,
                    onPressed: _loading
                        ? null
                        : _stage == 2
                            ? _save
                            : _next)),
          ]);
        })),
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) ErrorNote(message: _error!, onRetry: _load),
          if (_stage == 0) ..._cargo(),
          if (_stage == 1) ..._billing(),
          if (_stage == 2) ..._review(),
        ]);
  }

  List<Widget> _cargo() {
    final customer = _selectedCustomer;
    return [
      SectionTitle(
          title: tr('Customer'),
          action: TextButton.icon(
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(tr('New customer')),
              onPressed: _newCustomer)),
      if (_customers.isEmpty && !_loading)
        EmptyNote(
            icon: Icons.person_outline_rounded,
            title: tr('No customers'),
            body: tr('Tap New to add a customer.'))
      else if (customer == null)
        PaperCard(
            onTap: _pickCustomer,
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              const IconBadge(Icons.person_search_outlined, size: 44),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(tr('Choose a customer'),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    Text(tr('Search by name, code or phone'),
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.muted)),
                  ])),
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: AppColors.faint),
            ]))
      else
        PaperCard(
            onTap: _pickCustomer,
            padding: const EdgeInsets.all(14),
            border: const BorderSide(color: AppColors.primary, width: 1.5),
            child: Row(children: [
              LetterAvatar.customer(customer.name),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(customer.name,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    Text('${customer.code} · ${customer.phone}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.muted)),
                  ])),
              const SizedBox(width: 8),
              Text(tr('Change'),
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary)),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.primary),
            ])),
      const SizedBox(height: 18),
      SectionTitle(
          title: tr('Categories'),
          action: _picked.isEmpty
              ? null
              : Text(tr('{n} chosen', {'n': _picked.length}),
                  style:
                      const TextStyle(fontSize: 13, color: AppColors.muted))),
      PaperCard(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final name in _categories)
                CategoryChip(
                    label: name,
                    selected: _picked.contains(name),
                    onTap: () => _toggleCategory(name)),
            ]),
            const SizedBox(height: 6),
            if (_addingCategory) ...[
              const SizedBox(height: 6),
              TextField(
                  controller: _categoryName,
                  autofocus: true,
                  decoration:
                      InputDecoration(labelText: tr('New category name'))),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: AppButton(
                        label: tr('Add'),
                        kind: AppButtonKind.tonal,
                        busy: _savingCategory,
                        onPressed: _addCategory)),
                const SizedBox(width: 8),
                TextButton(
                    onPressed: _savingCategory
                        ? null
                        : () => setState(() => _addingCategory = false),
                    child: Text(tr('Cancel'))),
              ]),
              const SizedBox(height: 8),
            ] else
              TextButton.icon(
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4)),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(tr('New category')),
                  onPressed: () => setState(() => _addingCategory = true)),
          ])),
      for (final entry in _pieces.entries) ...[
        const SizedBox(height: 16),
        _PieceFields(
            name: entry.key,
            draft: entry.value,
            onChanged: () => setState(() {})),
      ],
      const SizedBox(height: 8),
    ];
  }

  List<Widget> _billing() {
    final shipping = _kgValue * _rateValue;
    return [
      PaperCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CardHeading(
            icon: Icons.scale_outlined,
            title: tr('Weight and rate'),
            subtitle:
                tr('Charged on the booked weight; pieces are billed apart.')),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: TextField(
                  controller: _kg,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                      labelText: tr('Booked kg'),
                      suffixText: 'kg',
                      helperText: tr('0 for devices only')))),
          const SizedBox(width: 10),
          Expanded(
              child: TextField(
                  controller: _rate,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                      labelText: tr('Rate per kg'),
                      prefixText: _currency == 'CNY' ? '¥ ' : '৳ ',
                      helperText: tr('Leave blank for 0')))),
        ]),
        const SizedBox(height: 14),
        FieldLabel(tr('Currency')),
        ScreenTabs(
            labels: _currencies,
            index: _currencies.indexOf(_currency),
            onChanged: (i) => setState(() => _currency = _currencies[i])),
        const Divider(height: 28),
        Row(children: [
          Expanded(
              child: Text(tr('Shipping charge'),
                  style:
                      const TextStyle(fontSize: 14, color: AppColors.inkSoft))),
          const SizedBox(width: 8),
          Text(formatMoney(shipping, _currency),
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()])),
        ]),
      ])),
      const SizedBox(height: 12),
      PaperCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CardHeading(
            icon: Icons.receipt_long_outlined,
            tone: ChipTone.neutral,
            title: tr('Contents and terms')),
        const SizedBox(height: 16),
        TextField(
            controller: _description,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
                labelText: tr('Description'),
                helperText: tr('Shown on the bill and to the hub.'))),
        const SizedBox(height: 14),
        FieldLabel(tr('Payment terms')),
        ScreenTabs(
            labels: [tr('Invoice'), 'COD', tr('Monthly')],
            index: _termValues.indexOf(_terms),
            onChanged: (i) => setState(() => _terms = _termValues[i])),
      ])),
      const SizedBox(height: 8),
    ];
  }

  List<Widget> _review() {
    final customer = _selectedCustomer;
    final flight = _selectedFlight;
    final kg = _kgValue;
    final rate = _rateValue;
    final shipping = kg * rate;
    final pieces = [
      for (final entry in _pieces.entries) (name: entry.key, draft: entry.value)
    ];
    final total = pieces.fold(
        shipping, (sum, piece) => sum + piece.draft.count * piece.draft.rate);
    final terms = _terms == 'cod'
        ? 'COD'
        : _terms == 'monthly'
            ? tr('Monthly')
            : tr('Invoice');
    return [
      MoneyHero(
          label: tr('Estimated charge · at booked weight'),
          amount: formatMoney(total, _currency),
          children: [
            HeroLines(lines: [
              (
                tr('Shipping · {kg} kg × {currency} {rate}', {
                  'kg': kg.toStringAsFixed(1),
                  'currency': _currency,
                  'rate': _number(rate)
                }),
                formatMoney(shipping, _currency)
              ),
              for (final piece in pieces)
                (
                  tr('{name} · {n} pcs × {currency} {rate}', {
                    'name': piece.name,
                    'n': piece.draft.count,
                    'currency': _currency,
                    'rate': _number(piece.draft.rate)
                  }),
                  formatMoney(piece.draft.count * piece.draft.rate, _currency)
                ),
            ]),
          ]),
      const SizedBox(height: 14),
      PaperCard(
          padding: EdgeInsets.zero,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: CardTitle(title: tr('Booking summary'))),
            Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 12, 14),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        Expanded(child: CapsLabel(tr('Cargo'))),
                        LinkText(label: tr('Edit'), onTap: () => _goTo(0)),
                      ]),
                      Row(children: [
                        LetterAvatar.customer(
                            customer?.name ?? _supplier ?? '?',
                            size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(customer?.name ?? _supplier ?? '—',
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700)),
                              if (customer != null)
                                Text('${customer.code} · ${customer.phone}',
                                    style: const TextStyle(
                                        fontSize: 13, color: AppColors.muted)),
                            ])),
                      ]),
                      const SizedBox(height: 12),
                      FactGrid(facts: [
                        Fact(tr('Categories'), _picked.join(', ')),
                        for (final piece in pieces)
                          Fact(
                              piece.name,
                              trn(
                                  piece.draft.count,
                                  '{n} piece · {currency} {rate} / piece',
                                  '{n} pieces · {currency} {rate} / piece', {
                                'currency': _currency,
                                'rate': _number(piece.draft.rate)
                              })),
                      ]),
                    ])),
            const Divider(height: 1, color: AppColors.lineSoft),
            Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 12, 16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        Expanded(child: CapsLabel(tr('Billing'))),
                        LinkText(label: tr('Edit'), onTap: () => _goTo(1)),
                      ]),
                      FactGrid(facts: [
                        Fact(tr('Weight'),
                            '${_kg.text.isEmpty ? '0' : _kg.text} kg'),
                        Fact(tr('Rate per kg'),
                            '$_currency ${_rate.text.isEmpty ? '0' : _rate.text}'),
                        Fact(tr('Payment terms'), terms),
                        if (_description.text.trim().isNotEmpty)
                          Fact(tr('Description'), _description.text.trim()),
                      ]),
                    ])),
          ])),
      const SizedBox(height: 18),
      SectionTitle(
          title: tr('Flight'),
          subtitle: tr('Optional now; you can assign one later.')),
      RowCard(children: [
        for (final row in _flights) _flightRow(row, kg),
        RadioRow(
            selected: _flight == null,
            title: tr('Assign later'),
            subtitle: tr('Create the shipment without a flight'),
            onTap: () => _chooseFlight(null)),
      ]),
      if (flight != null && flight.flyers.length > 1) ...[
        const SizedBox(height: 18),
        SectionTitle(
            title: tr('Flyer'),
            subtitle: tr('{flight} has {n} flyers. Who carries this cargo?',
                {'flight': flight.displayCode, 'n': flight.flyers.length})),
        _FlyerChoices(
            names: flight.flyers,
            selected: _flyer,
            onSelected: (name) => setState(() => _flyer = name)),
      ],
      const SizedBox(height: 8),
    ];
  }

  Widget _flightRow(FlightSummary row, double kg) {
    final selected = _flight == row.code;
    final left = row.leftKg;
    final after = left - kg;
    return RadioRow(
        selected: selected,
        title: '${row.displayCode} · ${shortDay(row.date)}',
        subtitle: selected
            ? tr('{left} kg left · {after} kg after this booking', {
                'left': left.toStringAsFixed(1),
                'after': after.toStringAsFixed(1)
              })
            : tr('{kg} kg left', {'kg': left.toStringAsFixed(1)}),
        trailing: !selected
            ? null
            : after >= 0
                ? StatusPill(label: tr('Fits'), tone: ChipTone.green)
                : StatusPill(label: tr('Over capacity'), tone: ChipTone.red),
        onTap: () => _chooseFlight(row.code));
  }
}

/// 950 rather than 950.0; keeps decimals when there are any.
String _number(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toString();

class _FlyerChoices extends StatelessWidget {
  const _FlyerChoices(
      {required this.names, required this.selected, required this.onSelected});
  final List<String> names;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    Widget choice(String name) {
      final on = name == selected;
      return Semantics(
          selected: on,
          inMutuallyExclusiveGroup: true,
          button: true,
          child: Material(
              color: AppColors.card,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                      color: on ? AppColors.primary : AppColors.field,
                      width: on ? 2 : 1)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                  onTap: () => onSelected(name),
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 56),
                      child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: Row(children: [
                            LetterAvatar(name,
                                size: 32,
                                color:
                                    on ? AppColors.primary : AppColors.lineSoft,
                                foreground:
                                    on ? Colors.white : AppColors.inkSoft),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Text(name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 15,
                                        height: 1.3,
                                        fontWeight: on
                                            ? FontWeight.w700
                                            : FontWeight.w600))),
                          ]))))));
    }

    return Column(children: [
      for (var i = 0; i < names.length; i += 2)
        Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: choice(names[i])),
              const SizedBox(width: 10),
              Expanded(
                  child: i + 1 < names.length
                      ? choice(names[i + 1])
                      : const SizedBox.shrink()),
            ])),
    ]);
  }
}

class _PieceDraft {
  _PieceDraft({required this.rate})
      : count = 1,
        units = [(model: '', serial: '')];

  int count;
  double rate;
  List<({String model, String serial})> units;

  void resize(int next) {
    count = next < 1 ? 1 : (next > 20 ? 20 : next);
    if (units.length > count) units = units.take(count).toList();
    while (units.length < count) {
      units.add((model: '', serial: ''));
    }
  }

  IntakePiece toPiece(String category, String currency) {
    return IntakePiece(
        category: category,
        count: count,
        rate: rate,
        currency: currency,
        units: units);
  }
}

IconData _pieceIcon(String name) {
  final lower = name.toLowerCase();
  if (lower.contains('laptop')) return Icons.laptop_rounded;
  if (lower.contains('mobile') || lower.contains('phone')) {
    return Icons.smartphone_rounded;
  }
  return Icons.devices_other_rounded;
}

class _PieceFields extends StatelessWidget {
  const _PieceFields(
      {required this.name, required this.draft, required this.onChanged});

  final String name;
  final _PieceDraft draft;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CardHeading(
              icon: _pieceIcon(name),
              title: tr('{name} pieces', {'name': name}),
              subtitle: tr("Count, price and each device's model and IMEI")),
          const SizedBox(height: 16),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  FieldLabel(tr('Quantity')),
                  QuantityStepper(
                      value: draft.count,
                      onChanged: (value) {
                        draft.resize(value);
                        onChanged();
                      }),
                ])),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  FieldLabel(tr('Price per piece')),
                  TextFormField(
                    key: ValueKey('$name-rate'),
                    initialValue: draft.rate == 0 ? '' : _number(draft.rate),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600),
                    decoration:
                        InputDecoration(hintText: '0', suffixText: tr('/ pc')),
                    onChanged: (value) =>
                        draft.rate = double.tryParse(value) ?? 0,
                  ),
                ])),
          ]),
          const SizedBox(height: 6),
          Text(tr('Price is prefilled from settings when a rate is saved.'),
              style: const TextStyle(
                  fontSize: 12, height: 1.4, color: AppColors.muted)),
          for (var i = 0; i < draft.units.length; i++) ...[
            const Divider(height: 28),
            Text(tr('Piece {n}', {'n': i + 1}),
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkSoft)),
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  flex: 9,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FieldLabel(tr('Model')),
                        TextFormField(
                          key: ValueKey('$name-model-$i'),
                          initialValue: draft.units[i].model,
                          onChanged: (value) => draft.units[i] =
                              (model: value, serial: draft.units[i].serial),
                        ),
                      ])),
              const SizedBox(width: 10),
              Expanded(
                  flex: 11,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FieldLabel(tr('Serial / IMEI')),
                        TextFormField(
                          key: ValueKey('$name-serial-$i'),
                          initialValue: draft.units[i].serial,
                          autocorrect: false,
                          decoration:
                              InputDecoration(hintText: tr('IMEI number')),
                          onChanged: (value) => draft.units[i] =
                              (model: draft.units[i].model, serial: value),
                        ),
                      ])),
            ]),
          ],
        ],
      ),
    );
  }
}

class _PickerSheet extends StatefulWidget {
  const _PickerSheet(
      {required this.title, required this.options, this.selected});
  final String title;
  final List<({String value, String title, String subtitle})> options;
  final String? selected;
  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  var _query = '';
  @override
  Widget build(BuildContext context) {
    final options = widget.options.where((item) =>
        '${item.title} ${item.subtitle}'.toLowerCase().contains(_query));
    return Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .72,
            child: Column(children: [
              Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
                  child: Row(children: [
                    Expanded(
                        child: Text(widget.title,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w600))),
                    IconButton(
                        tooltip: tr('Close'),
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded)),
                  ])),
              Padding(
                  padding: const EdgeInsets.all(20),
                  child: TextField(
                      decoration: InputDecoration(
                          hintText: tr('Search'),
                          prefixIcon: const Icon(Icons.search_rounded)),
                      onChanged: (value) =>
                          setState(() => _query = value.trim().toLowerCase()))),
              Expanded(
                  child: options.isEmpty
                      ? EmptyNote(
                          title: tr('No results found'),
                          body: tr('Try another name or code.'))
                      : ListView(children: [
                          for (final item in options)
                            ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 4),
                                leading:
                                    LetterAvatar.customer(item.title, size: 40),
                                title: Text(item.title),
                                subtitle: Text(item.subtitle),
                                trailing: item.value == widget.selected
                                    ? const Icon(Icons.check_rounded,
                                        color: AppColors.primary)
                                    : null,
                                onTap: () =>
                                    Navigator.pop(context, item.value)),
                        ])),
            ])));
  }
}
