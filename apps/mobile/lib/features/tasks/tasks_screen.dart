import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/session_user.dart';
import '../../data/models/task_item.dart';
import '../../data/repositories/task_repository.dart';
import '../../l10n/l10n.dart';
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
  var _assignTo = 'admin';
  var _composing = false;

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
      await widget.tasks.addNote(text,
          assignTo: widget.role == UserRole.admin ? _assignTo : null);
      if (!mounted) return;
      _note.clear();
      _composing = false;
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
    final open = [
      for (final item in _items)
        if (!item.done) item
    ];
    final done = [
      for (final item in _items)
        if (item.done) item
    ];
    return WorkspaceScaffold(
        title: widget.role == UserRole.hub ? tr('Hub tasks') : tr('Tasks'),
        root: widget.role == UserRole.hub,
        onRefresh: _load,
        actions: [
          Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Tooltip(
                  message: _composing ? tr('Close note') : tr('New note'),
                  child: AppButton(
                      label: _composing ? tr('Hide') : tr('Note'),
                      expand: false,
                      kind:
                          _composing ? AppButtonKind.quiet : AppButtonKind.teal,
                      onPressed: () => setState(() => _composing = !_composing),
                      icon: _composing
                          ? Icons.close_rounded
                          : Icons.add_rounded)))
        ],
        children: [
          Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                  tr('{open} pending · {done} done',
                      {'open': open.length, 'done': done.length}),
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.muted, height: 1.5))),
          if (_composing) ...[
            PaperCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  SectionTitle(title: tr('New note')),
                  TextField(
                      controller: _note,
                      minLines: 2,
                      maxLines: 4,
                      decoration:
                          InputDecoration(labelText: tr('Task description'))),
                  if (widget.role == UserRole.admin) ...[
                    const SizedBox(height: 12),
                    ChoiceChips(
                        options: [
                          (value: 'admin', label: tr('For myself')),
                          (value: 'hub', label: tr('Assign to hub'))
                        ],
                        selected: _assignTo,
                        onSelected: (value) =>
                            setState(() => _assignTo = value)),
                  ],
                  const SizedBox(height: 12),
                  AppButton(
                      label: tr('Add note'),
                      kind: AppButtonKind.teal,
                      busy: _busy,
                      onPressed: _add),
                ])),
            const SizedBox(height: 20),
          ],
          if (_loading)
            const LinearProgressIndicator(
                color: AppColors.teal, backgroundColor: AppColors.tealSoft),
          if (_error != null) ErrorNote(message: _error!, onRetry: _load),
          if (!_loading && open.isEmpty)
            EmptyNote(
                title: tr('No open tasks'),
                body: tr('New automatic tasks appear here.')),
          for (final item in open) ...[
            _TaskCard(item: item, onChanged: _load, onOpen: () => _open(item)),
            const SizedBox(height: 8),
          ],
          if (done.isNotEmpty) ...[
            const SizedBox(height: 12),
            SectionTitle(title: tr('Completed tasks')),
            for (final item in done) ...[
              Opacity(opacity: 0.7, child: PaperCard(child: Text(item.text))),
              const SizedBox(height: 8),
            ],
          ],
        ]);
  }

  void _open(TaskItem item) {
    if (item.opensReview) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const PaymentReviewScreen()));
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
  const _TaskCard(
      {required this.item, required this.onChanged, required this.onOpen});

  final TaskItem item;
  final Future<void> Function() onChanged;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final hint = item.opensReview
        ? tr('Completes when the payment is reviewed')
        : item.auto
            ? tr('Closes when the hub step is done')
            : null;
    final linked = item.opensReview || item.shipmentCode != null;
    return PaperCard(
      onTap: linked ? onOpen : null,
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        IconBadge(item.opensReview
            ? Icons.receipt_long_outlined
            : item.auto
                ? Icons.inventory_2_outlined
                : Icons.notes_rounded),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.text,
              style:
                  const TextStyle(fontWeight: FontWeight.w500, height: 1.45)),
          if (hint != null) ...[
            const SizedBox(height: 5),
            Text(hint,
                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ],
        ])),
        if (linked)
          const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.chevron_right_rounded,
                  size: 20, color: AppColors.muted))
        else if (item.canToggle)
          IconButton(
              tooltip: tr('Mark note done'),
              icon: const Icon(Icons.check_circle_outline_rounded,
                  color: AppColors.teal),
              onPressed: () async {
                try {
                  await AppScope.of(context).tasks.toggle(item.id);
                } on ApiException catch (error) {
                  if (context.mounted && error.status != 401) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(error.message)));
                  }
                }
                await onChanged();
              }),
      ]),
    );
  }
}

class AssignTaskScreen extends StatefulWidget {
  const AssignTaskScreen({super.key});

  @override
  State<AssignTaskScreen> createState() => _AssignTaskScreenState();
}

class _AssignTaskScreenState extends State<AssignTaskScreen> {
  final _note = TextEditingController();
  List<TaskItem> _hubTasks = const [];
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
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await AppScope.of(context).tasks.list(scope: 'hub');
      if (!mounted) return;
      setState(() => _hubTasks = items);
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
      await AppScope.of(context).tasks.addNote(text, assignTo: 'hub');
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
    final open = [
      for (final item in _hubTasks)
        if (!item.done) item
    ];
    return WorkspaceScaffold(
        title: tr('Assign a task to the hub'),
        root: false,
        onRefresh: _load,
        children: [
          Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                  tr(
                      'Manual notes. Automatic weigh, pack and courier tasks close on their own.'),
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.muted, height: 1.5))),
          TextField(
              controller: _note,
              decoration: InputDecoration(labelText: tr('What needs doing'))),
          const SizedBox(height: 8),
          AppButton(
              label: tr('Assign to hub'),
              kind: AppButtonKind.current,
              busy: _busy,
              onPressed: _add),
          const SizedBox(height: 16),
          if (_loading)
            const LinearProgressIndicator(
                color: AppColors.teal, backgroundColor: AppColors.tealSoft),
          if (_error != null) ErrorNote(message: _error!, onRetry: _load),
          if (!_loading && open.isEmpty)
            EmptyNote(
                title: tr('No open hub notes'),
                body: tr('Tasks you assign appear here.')),
          for (final item in open) ...[
            PaperCard(
                child: Text(item.text,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, height: 1.35))),
            const SizedBox(height: 8),
          ],
        ]);
  }
}
