import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/customer.dart';
import '../../data/models/flight.dart';
import '../../data/models/workspace.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ui.dart';
import '../admin/admin_shipment_screen.dart';
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

  Future<void> _pickFlight() async {
    final value = await _pick(
        tr('Choose a flight'),
        [
          (
            value: '',
            title: tr('Assign later'),
            subtitle: tr('Create the shipment without a flight')
          ),
          for (final flight in _flights)
            (
              value: flight.code,
              title: flight.displayCode,
              subtitle: tr('{date} · {kg} kg left',
                  {'date': flight.date, 'kg': flight.leftKg.toStringAsFixed(1)})
            ),
        ],
        _flight ?? '');
    if (!mounted || value == null) return;
    setState(() {
      _flight = value.isEmpty ? null : value;
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

  @override
  Widget build(BuildContext context) {
    final flight = _selectedFlight;
    return WorkspaceScaffold(
        title: tr('New shipment'),
        subtitle: tr('Step {step} of 3', {'step': _stage + 1}),
        toolbar: ScreenTabs(
            labels: [tr('1 · Cargo'), tr('2 · Billing'), tr('3 · Review')],
            index: _stage,
            enabledThrough: _stage,
            onChanged: (i) {
              if (i < _stage) setState(() => _stage = i);
            }),
        footer: ActionFooter(
            child: Row(children: [
          if (_stage > 0) ...[
            OutlinedButton(
                onPressed: _busy ? null : () => setState(() => _stage--),
                child: Text(tr('Previous step'))),
            const SizedBox(width: 12)
          ],
          Expanded(
              child: AppButton(
                  key: const Key('intake-next'),
                  label: _stage == 2 ? tr('Create shipment') : tr('Next'),
                  busy: _busy,
                  onPressed: _loading
                      ? null
                      : _stage == 2
                          ? _save
                          : _next)),
        ])),
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) ErrorNote(message: _error!, onRetry: _load),
          if (_stage == 0) ...[
            SectionTitle(
                title: tr('Customer'),
                action: TextButton.icon(
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(tr('New')),
                    onPressed: () async {
                      final created = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                              builder: (_) => const CustomerFormScreen()));
                      if (created == true && mounted) await _load();
                    })),
            if (_customers.isEmpty && !_loading)
              EmptyNote(
                  title: tr('No customers'),
                  body: tr('Tap New to add a customer.'))
            else
              DirectoryTile(
                  title: _selectedCustomer?.name ?? tr('Choose a customer'),
                  subtitle: _selectedCustomer == null
                      ? tr('Search by name, code or phone')
                      : '${_selectedCustomer!.code} · ${_selectedCustomer!.phone}',
                  icon: Icons.person_outline_rounded,
                  onTap: _pickCustomer),
            const SizedBox(height: 16),
            SectionTitle(title: tr('Categories')),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final name in _categories)
                  FilterChip(
                    label: Text(name),
                    selected: _picked.contains(name),
                    onSelected: (_) => _toggleCategory(name),
                    selectedColor: AppColors.tealSoft,
                    checkmarkColor: AppColors.tealInk,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_addingCategory) ...[
              TextField(
                  controller: _categoryName,
                  decoration:
                      InputDecoration(labelText: tr('New category name'))),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: AppButton(
                        label: tr('Add'),
                        kind: AppButtonKind.quiet,
                        busy: _savingCategory,
                        onPressed: _addCategory)),
                const SizedBox(width: 8),
                TextButton(
                    onPressed: _savingCategory
                        ? null
                        : () => setState(() => _addingCategory = false),
                    child: Text(tr('Cancel'))),
              ]),
            ] else
              Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                      icon: const Icon(Icons.add_rounded, size: 17),
                      label: Text(tr('New category')),
                      onPressed: () => setState(() => _addingCategory = true))),
            for (final entry in _pieces.entries) ...[
              const SizedBox(height: 12),
              _PieceFields(
                  name: entry.key,
                  draft: entry.value,
                  onChanged: () => setState(() {})),
            ],
            const SizedBox(height: 16),
          ],
          if (_stage == 1) ...[
            FormSection(title: tr('Charges and payment'), children: [
              SectionTitle(title: tr('Weight and rate')),
              TextField(
                  controller: _kg,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                      labelText: tr('Booked kg'),
                      helperText: tr('0 for devices only'))),
              const SizedBox(height: 8),
              TextField(
                  controller: _rate,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                      labelText: tr('Rate per kg'),
                      helperText: tr('Leave blank for 0'))),
              const SizedBox(height: 8),
              ChoiceChips(
                options: const [
                  (value: 'BDT', label: 'BDT'),
                  (value: 'CNY', label: 'CNY')
                ],
                selected: _currency,
                onSelected: (value) => setState(() => _currency = value),
              ),
              const SizedBox(height: 8),
              TextField(
                  controller: _description,
                  decoration: InputDecoration(labelText: tr('Description'))),
              const SizedBox(height: 16),
              SectionTitle(title: tr('Payment terms')),
              ChoiceChips(
                options: [
                  (value: 'invoice', label: tr('Invoice')),
                  (value: 'cod', label: 'COD'),
                  (value: 'monthly', label: tr('Monthly')),
                ],
                selected: _terms,
                onSelected: (value) => setState(() => _terms = value),
              ),
              const SizedBox(height: 16),
            ]),
          ],
          if (_stage == 2) ...[
            FormSection(title: tr('Booking summary'), children: [
              KvRow(
                  label: tr('Customer'),
                  value: _selectedCustomer?.name ?? _supplier ?? '—'),
              KvRow(label: tr('Categories'), value: _picked.join(', ')),
              KvRow(
                  label: tr('Weight'),
                  value: '${_kg.text.isEmpty ? '0' : _kg.text} kg'),
              KvRow(
                  label: tr('Rate per kg'),
                  value: '$_currency ${_rate.text.isEmpty ? '0' : _rate.text}'),
              KvRow(
                  label: tr('Payment terms'),
                  value: _terms == 'cod'
                      ? 'COD'
                      : _terms == 'monthly'
                          ? tr('Monthly')
                          : tr('Invoice')),
              if (_description.text.isNotEmpty)
                KvRow(label: tr('Description'), value: _description.text),
              for (final entry in _pieces.entries)
                KvRow(
                    label: entry.key,
                    value: trn(
                        entry.value.count,
                        '{n} piece · {currency} {rate} / piece',
                        '{n} pieces · {currency} {rate} / piece',
                        {'currency': _currency, 'rate': entry.value.rate})),
            ]),
            SectionTitle(
                title: tr('Flight'),
                subtitle: tr('Optional now; you can assign one later.')),
            DirectoryTile(
                title: flight?.displayCode ?? tr('Assign later'),
                subtitle: flight == null
                    ? tr('Tap to choose a flight')
                    : tr('{date} · {kg} kg left', {
                        'date': flight.date,
                        'kg': flight.leftKg.toStringAsFixed(1)
                      }),
                icon: Icons.flight_takeoff_rounded,
                onTap: _pickFlight),
            if (flight != null && flight.flyers.length > 1) ...[
              const SizedBox(height: 12),
              DirectoryTile(
                  title: _flyer ?? tr('Choose a flyer'),
                  subtitle: tr('Carries the cargo on this flight'),
                  icon: Icons.badge_outlined,
                  onTap: () async {
                    final value = await _pick(
                        tr('Choose a flyer'),
                        [
                          for (final name in flight.flyers)
                            (
                              value: name,
                              title: name,
                              subtitle: flight.displayCode
                            )
                        ],
                        _flyer);
                    if (mounted && value != null) {
                      setState(() => _flyer = value);
                    }
                  }),
            ],
          ],
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: '${draft.count}',
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: tr('Quantity')),
            onChanged: (value) {
              draft.resize(int.tryParse(value) ?? 1);
              onChanged();
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: draft.rate == 0 ? '' : draft.rate.toString(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
                labelText: tr('Price per piece'),
                helperText: tr('Prefilled from settings when a rate is saved')),
            onChanged: (value) => draft.rate = double.tryParse(value) ?? 0,
          ),
          for (var i = 0; i < draft.units.length; i++) ...[
            const SizedBox(height: 8),
            Text(tr('Piece {n}', {'n': i + 1}),
                style: const TextStyle(color: AppColors.muted)),
            TextFormField(
              initialValue: draft.units[i].model,
              decoration: InputDecoration(labelText: tr('Model')),
              onChanged: (value) => draft.units[i] =
                  (model: value, serial: draft.units[i].serial),
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: draft.units[i].serial,
              decoration: InputDecoration(labelText: tr('Serial / IMEI')),
              onChanged: (value) =>
                  draft.units[i] = (model: draft.units[i].model, serial: value),
            ),
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
                                title: Text(item.title),
                                subtitle: Text(item.subtitle),
                                trailing: item.value == widget.selected
                                    ? const Icon(Icons.check_rounded,
                                        color: AppColors.teal)
                                    : null,
                                onTap: () =>
                                    Navigator.pop(context, item.value)),
                        ])),
            ])));
  }
}
