import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/flight.dart';
import '../../data/models/flyer.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ui.dart';

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
      final flyers = await AppScope.of(context).flyers.list();
      if (!mounted) return;
      setState(() => _flyers = flyers);
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
      setState(() => _error = 'এয়ারলাইন ফ্লাইট নম্বর দিন।');
      return;
    }
    if (date == null) {
      setState(() => _error = 'তারিখ বেছে নিন।');
      return;
    }
    if (_picked.isEmpty) {
      setState(() => _error = 'অন্তত একজন ফ্লায়ার বেছে নিন।');
      return;
    }
    final actual = double.tryParse(_cost.text.trim()) ?? 0;
    final agency = double.tryParse(_agency.text.trim()) ?? 0;
    if (actual < 0 || agency < 0 || agency > actual) {
      setState(() => _error = 'এজেন্সি শেয়ার আসল খরচের বেশি হতে পারে না। খালি রাখলে ০।');
      return;
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
    final dateLabel = _date == null ? 'তারিখ বেছে নিন' : _iso(_date!);
    return Scaffold(
      appBar: const BackTitle(title: 'নতুন ফ্লাইট'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(pageGutter, 8, pageGutter, 32),
        children: [
          const PageHeader(
            title: 'নতুন ফ্লাইট',
            subtitle: 'ফ্লাইট নম্বর প্রতিদিন আবার আসে। বুকিং রেফারেন্স সার্ভার বানাবে। টাকার অঙ্ক না দিলে ০ সেভ হয় এবং কোনো অ্যাকাউন্ট থেকে কাটা হয় না।',
          ),
          if (_loading) const LinearProgressIndicator(color: AppColors.teal, backgroundColor: AppColors.tealSoft),
          TextField(controller: _code, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'এয়ারলাইন ফ্লাইট নম্বর')),
          const SizedBox(height: 12),
          AppButton(label: dateLabel, kind: AppButtonKind.quiet, onPressed: _pickDate),
          const SizedBox(height: 16),
          const SectionTitle(title: 'ফ্লায়ার', subtitle: 'যারা এই টিকিটে উড়বেন।'),
          if (_flyers.isEmpty && !_loading) const EmptyNote(title: 'ফ্লায়ার নেই', body: 'আগে ফ্লায়ার প্রোফাইল খুলুন।'),
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
          TextField(controller: _space, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'ক্যাপাসিটি kg', helperText: 'সাধারণত ৪৪ বা ৫২')),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: TextField(controller: _mobiles, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'মোবাইল'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _laptops, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'ল্যাপটপ'))),
            ],
          ),
          const SizedBox(height: 8),
          TextField(controller: _cost, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'আসল টিকিট খরচ (BDT)', helperText: 'জানা না থাকলে খালি রাখুন')),
          const SizedBox(height: 8),
          TextField(controller: _agency, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'এজেন্সি শেয়ার (BDT)')),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.danger, height: 1.35)),
          ],
          const SizedBox(height: 16),
          AppButton(label: 'ফ্লাইট সেভ করুন', kind: AppButtonKind.current, busy: _busy, onPressed: _save),
        ],
      ),
    );
  }
}

String _iso(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
