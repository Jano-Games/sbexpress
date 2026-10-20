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
        _flights = [for (final flight in flights) if (flight.status == 'upcoming') flight];
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

  bool _isPiece(String name) => _pcsRates.containsKey(name) || RegExp('mobile|laptop|drone', caseSensitive: false).hasMatch(name);

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
    if (name.isEmpty) return;
    try {
      await AppScope.of(context).settings.addCategory(name);
      _categoryName.clear();
      if (!_categories.contains(name)) _categories = [..._categories, name];
      _toggleCategory(name);
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
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
      await Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => AdminShipmentScreen(code: code)));
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final flight = _selectedFlight;
    return Scaffold(
      appBar: const BackTitle(title: 'শিপমেন্ট ইনটেক'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(pageGutter, 8, pageGutter, 32),
        children: [
          const PageHeader(
            title: 'শিপমেন্ট ইনটেক',
            subtitle: 'কাস্টমার, কার্গো, তারপর চাইলে ফ্লাইট। রেট না জানলে খালি রাখুন — ০ সেভ হবে, পরে বিল ঠিক করা যাবে।',
          ),
          if (_loading) const LinearProgressIndicator(color: AppColors.teal, backgroundColor: AppColors.tealSoft),
          if (_error != null) ...[
            ErrorNote(message: _error!, onRetry: _load),
            const SizedBox(height: 12),
          ],
          const SectionTitle(title: 'কাস্টমার'),
          if (_customers.isEmpty && !_loading)
            const EmptyNote(title: 'কাস্টমার নেই', body: 'আগে একজন কাস্টমার যোগ করুন।')
          else
            for (final customer in _customers) ...[
              _SelectRow(
                title: customer.name,
                subtitle: '${customer.code} · ${customer.phone}',
                selected: _supplier == customer.code,
                onTap: () => setState(() => _supplier = customer.code),
              ),
              const SizedBox(height: 8),
            ],
          AppButton(
            label: 'নতুন কাস্টমার',
            kind: AppButtonKind.quiet,
            onPressed: () async {
              final created = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const CustomerFormScreen()));
              if (created == true) await _load();
            },
          ),
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
          TextField(controller: _categoryName, decoration: const InputDecoration(labelText: 'নতুন ক্যাটাগরি')),
          const SizedBox(height: 8),
          AppButton(label: 'ক্যাটাগরি যোগ করুন', kind: AppButtonKind.quiet, onPressed: _addCategory),
          for (final entry in _pieces.entries) ...[
            const SizedBox(height: 12),
            _PieceFields(name: entry.key, draft: entry.value, onChanged: () => setState(() {})),
          ],
          const SizedBox(height: 16),
          const SectionTitle(title: 'ওজন ও রেট'),
          TextField(controller: _kg, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'বুকড kg', helperText: 'ডিভাইস-অনলি হলে ০')),
          const SizedBox(height: 8),
          TextField(controller: _rate, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'প্রতি kg রেট', helperText: 'খালি রাখলে ০')),
          const SizedBox(height: 8),
          ChoiceChips(
            options: const [(value: 'BDT', label: 'BDT'), (value: 'CNY', label: 'CNY')],
            selected: _currency,
            onSelected: (value) => setState(() => _currency = value),
          ),
          const SizedBox(height: 8),
          TextField(controller: _description, decoration: const InputDecoration(labelText: 'বিবরণ')),
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
          const SectionTitle(title: 'ফ্লাইট', subtitle: 'এখন না দিলে পরে অ্যাসাইন করা যাবে।'),
          _SelectRow(title: 'এখন নয়', subtitle: 'ফ্লাইট ছাড়া ইনটেক', selected: _flight == null, onTap: () => setState(() {
            _flight = null;
            _flyer = null;
          })),
          const SizedBox(height: 8),
          for (final row in _flights) ...[
            _SelectRow(
              title: row.displayCode,
              subtitle: '${row.date} · ${row.leftKg.toStringAsFixed(1)} kg বাকি · ${row.flyers.join(', ')}',
              selected: _flight == row.code,
              onTap: () => setState(() {
                _flight = row.code;
                _flyer = row.flyers.length == 1 ? row.flyers.first : null;
              }),
            ),
            const SizedBox(height: 8),
          ],
          if (flight != null && flight.flyers.length > 1) ...[
            const Text('ফ্লায়ার', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            for (final name in flight.flyers) ...[
              _SelectRow(title: name, subtitle: 'এই ফ্লাইটের ফ্লায়ার', selected: _flyer == name, onTap: () => setState(() => _flyer = name)),
              const SizedBox(height: 8),
            ],
          ],
          const SizedBox(height: 8),
          AppButton(label: 'শিপমেন্ট তৈরি করুন', kind: AppButtonKind.current, busy: _busy, onPressed: _save),
        ],
      ),
    );
  }
}

class _PieceDraft {
  _PieceDraft({required this.rate}) : count = 1, units = [(model: '', serial: '')];

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
    return IntakePiece(category: category, count: count, rate: rate, currency: currency, units: units);
  }
}

class _PieceFields extends StatelessWidget {
  const _PieceFields({required this.name, required this.draft, required this.onChanged});

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
            decoration: const InputDecoration(labelText: 'পিস রেট', helperText: 'সেটিংসের রেট থাকলে সেটা বসানো আছে'),
            onChanged: (value) => draft.rate = double.tryParse(value) ?? 0,
          ),
          for (var i = 0; i < draft.units.length; i++) ...[
            const SizedBox(height: 8),
            Text('পিস ${i + 1}', style: const TextStyle(color: AppColors.muted)),
            TextFormField(
              initialValue: draft.units[i].model,
              decoration: const InputDecoration(labelText: 'মডেল'),
              onChanged: (value) => draft.units[i] = (model: value, serial: draft.units[i].serial),
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: draft.units[i].serial,
              decoration: const InputDecoration(labelText: 'সিরিয়াল / IMEI'),
              onChanged: (value) => draft.units[i] = (model: draft.units[i].model, serial: value),
            ),
          ],
        ],
      ),
    );
  }
}

class _SelectRow extends StatelessWidget {
  const _SelectRow({required this.title, required this.subtitle, required this.selected, required this.onTap});

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.tealSoft : AppColors.card,
      borderRadius: BorderRadius.circular(cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(cardRadius),
        child: Container(
          constraints: const BoxConstraints(minHeight: minTouchTarget),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(cardRadius),
            border: Border.all(color: selected ? AppColors.teal : AppColors.line, width: selected ? 1.6 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(subtitle, style: const TextStyle(color: AppColors.muted, height: 1.3)),
            ],
          ),
        ),
      ),
    );
  }
}
