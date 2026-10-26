import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/session_user.dart';
import '../../data/models/task_item.dart';
import '../../data/repositories/task_repository.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/team_parts.dart';
import '../../widgets/ui.dart';
import '../admin/admin_shipment_screen.dart';
import '../admin/payment_review_screen.dart';
import '../shipments/shipment_process_screen.dart';

/// Automatic tasks close themselves; manual notes are ticked off here.
/// Admins open it from More; the hub has it as a bottom tab.
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
    final reviews = [
      for (final item in open)
        if (item.opensReview) item
    ];
    final steps = [
      for (final item in open)
        if (!item.opensReview && item.auto) item
    ];
    final notes = [
      for (final item in open)
        if (!item.opensReview && !item.auto) item
    ];
    final hub = widget.role == UserRole.hub;
    return WorkspaceScaffold(
        title: hub ? tr('Hub tasks') : tr('Tasks'),
        subtitle: tr('{open} pending · {done} done',
            {'open': open.length, 'done': done.length}),
        root: hub,
        onRefresh: _load,
        actions: [
          Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Tooltip(
                  message: _composing ? tr('Close note') : tr('New note'),
                  child: BarPillButton(
                      label: _composing ? tr('Hide') : tr('Note'),
                      outlined: _composing,
                      icon:
                          _composing ? Icons.close_rounded : Icons.add_rounded,
                      onPressed: () =>
                          setState(() => _composing = !_composing)))),
        ],
        children: [
          if (_composing) ...[
            _composer(),
            const SizedBox(height: 20),
          ],
          if (_loading && _items.isEmpty) const LinearProgressIndicator(),
          if (_error != null) ErrorNote(message: _error!, onRetry: _load),
          if (!_loading && open.isEmpty)
            EmptyNote(
                icon: Icons.task_alt_rounded,
                title: tr('No open tasks'),
                body: tr('New automatic tasks appear here.')),
          if (reviews.isNotEmpty)
            _Section(
                title: tr('Payment reviews'),
                caption: tr('Close on their own'),
                children: [
                  for (final item in reviews)
                    _TaskRow(item: item, onOpen: () => _open(item)),
                ]),
          if (steps.isNotEmpty)
            _Section(
                title: tr('Shipment steps'),
                caption: tr('Close on their own'),
                children: [
                  for (final item in steps)
                    _TaskRow(
                        item: item,
                        onOpen: item.shipmentCode == null
                            ? null
                            : () => _open(item)),
                ]),
          if (notes.isNotEmpty)
            _Section(
                title: tr('Your notes'),
                caption: tr('Tick when done'),
                children: [
                  for (final item in notes)
                    _TaskRow(
                        item: item,
                        onOpen: item.shipmentCode == null
                            ? null
                            : () => _open(item),
                        onDone: item.canToggle ? () => _toggle(item) : null),
                ]),
          if (done.isNotEmpty)
            _Section(
                title: tr('Completed'),
                caption: '${done.length}',
                children: [
                  for (final item in done) _DoneRow(item: item),
                ]),
        ]);
  }

  Widget _composer() => FormCard(title: tr('New note'), gap: 12, children: [
        LabeledField(
            label: tr('Task description'),
            child: TextField(
                controller: _note,
                minLines: 2,
                maxLines: 4,
                autofocus: false,
                textCapitalization: TextCapitalization.sentences)),
        if (widget.role == UserRole.admin)
          LabeledField(
              label: tr('Who does it'),
              child: SegmentPicker<String>(
                  options: [
                    (
                      value: 'admin',
                      label: tr('For myself'),
                      icon: Icons.person_outline_rounded
                    ),
                    (
                      value: 'hub',
                      label: tr('Assign to hub'),
                      icon: Icons.inventory_2_outlined
                    ),
                  ],
                  selected: _assignTo,
                  onChanged: (value) => setState(() => _assignTo = value))),
        AppButton(
            label: tr('Add note'),
            icon: Icons.add_rounded,
            kind: AppButtonKind.teal,
            busy: _busy,
            onPressed: _add),
      ]);

  Future<void> _toggle(TaskItem item) async {
    try {
      await AppScope.of(context).tasks.toggle(item.id);
    } on ApiException catch (error) {
      if (mounted && error.status != 401) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
    await _load();
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

class _Section extends StatelessWidget {
  const _Section(
      {required this.title, required this.caption, required this.children});
  final String title, caption;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionTitle(title: title, action: SectionCount(caption)),
        SurfaceGroup(children: children),
      ]));
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.item, this.onOpen, this.onDone});

  final TaskItem item;
  final VoidCallback? onOpen;

  /// Manual notes that are not linked to a shipment are ticked off.
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final hint = item.opensReview
        ? tr('Completes when the payment is reviewed')
        : item.auto
            ? tr('Closes when the hub step is done')
            : null;
    final review = item.opensReview;
    return InkWell(
        onTap: onOpen,
        child: Padding(
            padding: EdgeInsets.fromLTRB(
                14, 12, onOpen == null && onDone != null ? 6 : 14, 12),
            child: Row(children: [
              IconBadge(
                  review
                      ? Icons.receipt_long_outlined
                      : item.auto
                          ? Icons.inventory_2_outlined
                          : Icons.sticky_note_2_outlined,
                  tone: review ? ChipTone.amber : ChipTone.blue),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(item.text,
                        style: TextStyle(
                            fontSize: 15,
                            height: 1.4,
                            fontWeight: hint == null
                                ? FontWeight.w500
                                : FontWeight.w600)),
                    if (hint != null) ...[
                      const SizedBox(height: 2),
                      Row(children: [
                        const Icon(Icons.autorenew_rounded,
                            size: 13, color: AppColors.muted),
                        const SizedBox(width: 5),
                        Expanded(
                            child: Text(hint,
                                style: const TextStyle(
                                    fontSize: 12,
                                    height: 1.35,
                                    color: AppColors.muted))),
                      ]),
                    ],
                  ])),
              if (onOpen != null)
                const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(Icons.chevron_right_rounded,
                        size: 20, color: AppColors.faint))
              else if (onDone != null)
                IconButton(
                    tooltip: tr('Mark note done'),
                    color: AppColors.primary,
                    onPressed: onDone,
                    icon: const Icon(Icons.check_circle_outline_rounded,
                        size: 24)),
            ])));
  }
}

class _DoneRow extends StatelessWidget {
  const _DoneRow({required this.item});
  final TaskItem item;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
                color: AppColors.okSoft, shape: BoxShape.circle),
            child:
                const Icon(Icons.check_rounded, size: 16, color: AppColors.ok)),
        const SizedBox(width: 12),
        Expanded(
            child: Text(item.text,
                style: const TextStyle(
                    fontSize: 14, height: 1.45, color: AppColors.muted))),
      ]));
}

/// Admin form for a manual note that the hub ticks off.
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
          FormCard(gap: 12, children: [
            LabeledField(
                label: tr('What needs doing'),
                child: TextField(
                    controller: _note,
                    minLines: 2,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences)),
            AppButton(
                label: tr('Assign to hub'),
                icon: Icons.inventory_2_outlined,
                kind: AppButtonKind.current,
                busy: _busy,
                onPressed: _add),
          ]),
          const SizedBox(height: 14),
          TipNote(
              text: tr(
                  'Manual notes. Automatic weigh, pack and courier tasks close on their own.')),
          const SizedBox(height: 20),
          if (_loading && _hubTasks.isEmpty) const LinearProgressIndicator(),
          if (_error != null) ErrorNote(message: _error!, onRetry: _load),
          if (!_loading && open.isEmpty)
            EmptyNote(
                icon: Icons.sticky_note_2_outlined,
                title: tr('No open hub notes'),
                body: tr('Tasks you assign appear here.'))
          else if (open.isNotEmpty) ...[
            SectionTitle(
                title: tr('Hub tasks'), action: SectionCount('${open.length}')),
            SurfaceGroup(children: [
              for (final item in open) _TaskRow(item: item),
            ]),
          ],
        ]);
  }
}
