import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/customer.dart';
import '../../data/models/flight.dart';
import '../../data/models/workspace.dart';
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
        'কাস্টমার বেছে নিন',
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
        'ফ্লাইট বেছে নিন',
        [
          (
            value: '',
            title: 'পরে অ্যাসাইন করব',
            subtitle: 'ফ্লাইট ছাড়া শিপমেন্ট তৈরি করুন'
          ),
          for (final flight in _flights)
            (
              value: flight.code,
              title: flight.displayCode,
              subtitle:
                  '${flight.date} · ${flight.leftKg.toStringAsFixed(1)} kg বাকি'
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
      setState(() => _error = 'কাস্টমার বেছে নিন।');
      return;
    }
    if (_picked.isEmpty) {
      setState(() => _error = 'অন্তত একটি ক্যাটাগরি বেছে নিন।');
      return;
    }
    final kg = double.tryParse(_kg.text.trim()) ?? 0;
    final rate = double.tryParse(_rate.text.trim()) ?? 0;
    if (kg < 0 || rate < 0) {
      setState(() => _error = 'ওজন ও রেট ০ বা তার বেশি হতে হবে।');
      return;
    }
    final pieces = <IntakePiece>[];
    for (final name in _picked) {
      final draft = _pieces[name];
      if (draft == null) continue;
      if (draft.count < 1) {
        setState(() => _error = '$name-এর সংখ্যা দিন।');
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
          ? 'কাস্টমার বেছে নিন।'
          : 'অন্তত একটি ক্যাটাগরি বেছে নিন।');
      return;
    }
    if (_stage == 1 &&
        ((double.tryParse(_kg.text.trim()) ?? 0) < 0 ||
            (double.tryParse(_rate.text.trim()) ?? 0) < 0)) {
      setState(() => _error = 'ওজন ও রেট ০ বা তার বেশি হতে হবে।');
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
        title: 'নতুন শিপমেন্ট',
        subtitle: 'ধাপ ${_stage + 1} / 3',
        toolbar: ScreenTabs(
            labels: const ['১ · পণ্য', '২ · বিল', '৩ · পর্যালোচনা'],
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
                child: const Text('আগের ধাপ')),
            const SizedBox(width: 12)
          ],
          Expanded(
              child: AppButton(
                  key: const Key('intake-next'),
                  label: _stage == 2 ? 'শিপমেন্ট তৈরি করুন' : 'পরের ধাপ',
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
                title: 'কাস্টমার',
                action: TextButton.icon(
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('নতুন'),
                    onPressed: () async {
                      final created = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                              builder: (_) => const CustomerFormScreen()));
                      if (created == true && mounted) await _load();
                    })),
            if (_customers.isEmpty && !_loading)
              const EmptyNote(
                  title: 'কাস্টমার নেই',
                  body: 'নতুন বাটনে চাপ দিয়ে কাস্টমার যোগ করুন।')
            else
              DirectoryTile(
                  title: _selectedCustomer?.name ?? 'কাস্টমার বেছে নিন',
                  subtitle: _selectedCustomer == null
                      ? 'নাম, কোড বা ফোন দিয়ে খুঁজুন'
                      : '${_selectedCustomer!.code} · ${_selectedCustomer!.phone}',
                  icon: Icons.person_outline_rounded,
                  onTap: _pickCustomer),
            const SizedBox(height: 16),
            const SectionTitle(title: 'ক্যাটাগরি'),
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
                      const InputDecoration(labelText: 'নতুন ক্যাটাগরির নাম')),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: AppButton(
                        label: 'যোগ করুন',
                        kind: AppButtonKind.quiet,
                        busy: _savingCategory,
                        onPressed: _addCategory)),
                const SizedBox(width: 8),
                TextButton(
                    onPressed: _savingCategory
                        ? null
                        : () => setState(() => _addingCategory = false),
                    child: const Text('বাতিল')),
              ]),
            ] else
              Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                      icon: const Icon(Icons.add_rounded, size: 17),
                      label: const Text('নতুন ক্যাটাগরি'),
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
            FormSection(title: 'চার্জ ও পেমেন্ট', children: [
              const SectionTitle(title: 'ওজন ও রেট'),
              TextField(
                  controller: _kg,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'বুকড kg', helperText: 'ডিভাইস-অনলি হলে ০')),
              const SizedBox(height: 8),
              TextField(
                  controller: _rate,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'প্রতি kg রেট', helperText: 'খালি রাখলে ০')),
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
                  decoration: const InputDecoration(labelText: 'বিবরণ')),
              const SizedBox(height: 16),
              const SectionTitle(title: 'পেমেন্ট টার্ম'),
              ChoiceChips(
                options: const [
                  (value: 'invoice', label: 'ইনভয়েস'),
                  (value: 'cod', label: 'COD'),
                  (value: 'monthly', label: 'মাসিক'),
                ],
                selected: _terms,
                onSelected: (value) => setState(() => _terms = value),
              ),
              const SizedBox(height: 16),
            ]),
          ],
          if (_stage == 2) ...[
            FormSection(title: 'বুকিংয়ের সারসংক্ষেপ', children: [
              KvRow(
                  label: 'কাস্টমার',
                  value: _selectedCustomer?.name ?? _supplier ?? '—'),
              KvRow(label: 'ক্যাটাগরি', value: _picked.join(', ')),
              KvRow(
                  label: 'ওজন',
                  value: '${_kg.text.isEmpty ? '0' : _kg.text} kg'),
              KvRow(
                  label: 'প্রতি kg রেট',
                  value: '$_currency ${_rate.text.isEmpty ? '0' : _rate.text}'),
              KvRow(
                  label: 'পেমেন্ট টার্ম',
                  value: _terms == 'cod'
                      ? 'COD'
                      : _terms == 'monthly'
                          ? 'মাসিক'
                          : 'ইনভয়েস'),
              if (_description.text.isNotEmpty)
                KvRow(label: 'বিবরণ', value: _description.text),
              for (final entry in _pieces.entries)
                KvRow(
                    label: entry.key,
                    value:
                        '${entry.value.count} পিস · $_currency ${entry.value.rate} / পিস'),
            ]),
            const SectionTitle(
                title: 'ফ্লাইট',
                subtitle: 'এখন না দিলে পরে অ্যাসাইন করা যাবে।'),
            DirectoryTile(
                title: flight?.displayCode ?? 'পরে অ্যাসাইন করব',
                subtitle: flight == null
                    ? 'ফ্লাইট বেছে নিতে চাপুন'
                    : '${flight.date} · ${flight.leftKg.toStringAsFixed(1)} kg বাকি',
                icon: Icons.flight_takeoff_rounded,
                onTap: _pickFlight),
            if (flight != null && flight.flyers.length > 1) ...[
              const SizedBox(height: 12),
              DirectoryTile(
                  title: _flyer ?? 'ফ্লায়ার বেছে নিন',
                  subtitle: 'এই ফ্লাইটে পণ্য বহন করবেন',
                  icon: Icons.badge_outlined,
                  onTap: () async {
                    final value = await _pick(
                        'ফ্লায়ার বেছে নিন',
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
            decoration: const InputDecoration(labelText: 'সংখ্যা'),
            onChanged: (value) {
              draft.resize(int.tryParse(value) ?? 1);
              onChanged();
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: draft.rate == 0 ? '' : draft.rate.toString(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
                labelText: 'পিস রেট',
                helperText: 'সেটিংসের রেট থাকলে সেটা বসানো আছে'),
            onChanged: (value) => draft.rate = double.tryParse(value) ?? 0,
          ),
          for (var i = 0; i < draft.units.length; i++) ...[
            const SizedBox(height: 8),
            Text('পিস ${i + 1}',
                style: const TextStyle(color: AppColors.muted)),
            TextFormField(
              initialValue: draft.units[i].model,
              decoration: const InputDecoration(labelText: 'মডেল'),
              onChanged: (value) => draft.units[i] =
                  (model: value, serial: draft.units[i].serial),
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: draft.units[i].serial,
              decoration: const InputDecoration(labelText: 'সিরিয়াল / IMEI'),
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
                        tooltip: 'বন্ধ করুন',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded)),
                  ])),
              Padding(
                  padding: const EdgeInsets.all(20),
                  child: TextField(
                      decoration: const InputDecoration(
                          hintText: 'খুঁজুন',
                          prefixIcon: Icon(Icons.search_rounded)),
                      onChanged: (value) =>
                          setState(() => _query = value.trim().toLowerCase()))),
              Expanded(
                  child: options.isEmpty
                      ? const EmptyNote(
                          title: 'কোনো ফল পাওয়া যায়নি',
                          body: 'অন্য নাম বা কোড দিয়ে খুঁজুন।')
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
