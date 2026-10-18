import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/session_user.dart';
import '../../data/models/task_item.dart';
import '../../data/repositories/task_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ui.dart';
import '../admin/admin_shipment_screen.dart';
import '../admin/payment_review_screen.dart';
import '../shipments/shipment_process_screen.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key, required this.role, required this.tasks});

  final UserRole role;
  final TaskRepository tasks;

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final _note = TextEditingController();
  List<TaskItem> _items = const [];
  String? _error;
  var _loading = true;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.tasks.list();
      if (!mounted) return;
      setState(() => _items = items);
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

  Future<void> _add() async {
    final text = _note.text.trim();
    if (text.isEmpty) return;
    setState(() => _busy = true);
    try {
      await widget.tasks.addNote(text);
      _note.clear();
      await _load();
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final open = [for (final item in _items) if (!item.done) item];
    final done = [for (final item in _items) if (item.done) item];
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.teal,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            children: [
              Text(widget.role == UserRole.hub ? 'হাবের কাজ' : 'কাজ', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text('অটো কাজ শিপমেন্টের ধাপ শেষ হলে নিজে বন্ধ হয়।', style: TextStyle(color: AppColors.muted, height: 1.35)),
              const SizedBox(height: 12),
              TextField(controller: _note, decoration: const InputDecoration(labelText: 'নিজের নোট')),
              const SizedBox(height: 8),
              AppButton(label: 'নোট যোগ করুন', kind: AppButtonKind.teal, busy: _busy, onPressed: _add),
              const SizedBox(height: 16),
              if (_loading) const LinearProgressIndicator(color: AppColors.teal, backgroundColor: AppColors.tealSoft),
              if (_error != null) ErrorNote(message: _error!, onRetry: _load),
              if (!_loading && open.isEmpty) const EmptyNote(title: 'খোলা কাজ নেই', body: 'নতুন অটো কাজ এলে এখানে দেখা যাবে।'),
              for (final item in open) ...[
                _TaskCard(item: item, role: widget.role, onChanged: _load, onOpen: () => _open(item)),
                const SizedBox(height: 8),
              ],
              if (done.isNotEmpty) ...[
                const SizedBox(height: 12),
                const SectionTitle(title: 'শেষ হওয়া'),
                for (final item in done) ...[
                  Opacity(opacity: 0.7, child: PaperCard(child: Text(item.text))),
                  const SizedBox(height: 8),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _open(TaskItem item) {
    if (item.opensReview) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PaymentReviewScreen()));
      return;
    }
    final code = item.shipmentCode;
    if (code == null) return;
    final screen = switch (widget.role) {
      UserRole.hub => ShipmentProcessScreen(code: code),
      UserRole.admin => AdminShipmentScreen(code: code),
    };
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.item, required this.role, required this.onChanged, required this.onOpen});

  final TaskItem item;
  final UserRole role;
  final Future<void> Function() onChanged;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final hint = item.opensReview
        ? 'পেমেন্ট রিভিউতে শেষ হবে'
        : item.auto
            ? 'হাবের ধাপ শেষ হলে বন্ধ হবে'
            : null;
    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.text, style: const TextStyle(fontWeight: FontWeight.w600, height: 1.35)),
          if (item.auto) const Padding(padding: EdgeInsets.only(top: 6), child: StatusPill(label: 'অটো')),
          if (hint != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(hint, style: const TextStyle(color: AppColors.muted))),
          const SizedBox(height: 12),
          if (item.opensReview || item.shipmentCode != null)
            AppButton(label: item.opensReview ? 'রিভিউ খুলুন' : 'শিপমেন্ট খুলুন', kind: AppButtonKind.current, onPressed: onOpen)
          else if (item.canToggle)
            AppButton(
              label: 'নোট শেষ',
              kind: AppButtonKind.teal,
              onPressed: () async {
                try {
                  await AppScope.of(context).tasks.toggle(item.id);
                } on ApiException catch (error) {
                  if (context.mounted && error.status != 401) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
                  }
                }
                await onChanged();
              },
            ),
        ],
      ),
    );
  }
}
