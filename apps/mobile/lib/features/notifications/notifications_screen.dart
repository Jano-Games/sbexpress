import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/app_notification.dart';
import '../../data/models/hub_flight.dart';
import '../../data/models/session_user.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ui.dart';
import 'notification_targets.dart';

/// The bell on the home screens, with the unread count. It checks again every
/// minute and a half, when the app comes back, and after the list closes.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => NotificationBellState();
}

class NotificationBellState extends State<NotificationBell>
    with WidgetsBindingObserver {
  var _unread = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 90), (_) => reload());
    WidgetsBinding.instance.addPostFrameCallback((_) => reload());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) reload();
  }

  Future<void> reload() async {
    if (!mounted) return;
    try {
      final unread = await AppScope.of(context).notifications.unread();
      if (mounted && unread != _unread) setState(() => _unread = unread);
    } catch (_) {
      // The bell stays as it was; the list shows any error.
    }
  }

  Future<void> _open() async {
    await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()));
    await reload();
  }

  @override
  Widget build(BuildContext context) {
    final label = _unread > 9 ? '9+' : '$_unread';
    return Semantics(
      button: true,
      label: _unread == 0
          ? tr('Notifications')
          : trn(_unread, '{n} unread notification', '{n} unread notifications'),
      excludeSemantics: true,
      child: SizedBox(
        width: 52,
        height: 52,
        child: Stack(alignment: Alignment.center, children: [
          Material(
            color: AppColors.card,
            shape: const CircleBorder(side: BorderSide(color: AppColors.line)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: const Key('notification-bell'),
              onTap: _open,
              child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(Icons.notifications_none_rounded,
                      size: 23, color: AppColors.ink)),
            ),
          ),
          if (_unread > 0)
            Positioned(
              top: 4,
              right: 3,
              child: IgnorePointer(
                child: Container(
                  key: const Key('notification-badge'),
                  constraints:
                      const BoxConstraints(minWidth: 19, minHeight: 19),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: AppColors.alert,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.card, width: 2)),
                  child: Text(label,
                      textScaler: TextScaler.noScaling,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          height: 1.2,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  NotificationList? _data;
  String? _error;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await AppScope.of(context).notifications.list();
      if (mounted) setState(() => _data = data);
    } on ApiException catch (error) {
      if (mounted && error.status != 401) {
        setState(() => _error = error.message);
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _readAll() async {
    final data = _data;
    if (data == null || data.unread == 0) return;
    setState(() => _data = NotificationList(
        notifications: [for (final n in data.notifications) n.markedRead()],
        unread: 0));
    try {
      await AppScope.of(context).notifications.readAll();
    } catch (_) {
      if (mounted) await _load();
    }
  }

  Future<void> _open(AppNotification note) async {
    final scope = AppScope.of(context);
    final data = _data;
    if (!note.read && data != null) {
      setState(() => _data = NotificationList(notifications: [
            for (final n in data.notifications)
              n.id == note.id ? n.markedRead() : n
          ], unread: data.unread > 0 ? data.unread - 1 : 0));
      unawaited(scope.notifications.read(note.id).catchError((_) {}));
    }
    final role = scope.session.user?.role ?? UserRole.hub;
    final target = notificationTarget(note, role);
    if (target == null) return;
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => target));
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final unread = data?.unread ?? 0;
    return WorkspaceScaffold(
      title: tr('Notifications'),
      subtitle: data == null
          ? null
          : unread == 0
              ? tr('All read')
              : tr('{n} unread', {'n': unread}),
      actions: [
        if (unread > 0)
          TextButton(
              key: const Key('notifications-read-all'),
              onPressed: _readAll,
              child: Text(tr('Mark all read'))),
      ],
      onRefresh: _load,
      children: [
        if (_loading && data == null) const LinearProgressIndicator(),
        if (_error != null) ErrorNote(message: _error!, onRetry: _load),
        if (data != null && data.notifications.isEmpty)
          EmptyNote(
              icon: Icons.notifications_none_rounded,
              title: tr('No notifications yet'),
              body:
                  tr('New flights, landings and sorting steps show up here.')),
        if (data != null)
          for (final (day, notes) in _byDay(data.notifications)) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 0, 8),
              child: Text(day,
                  style: const TextStyle(
                      fontSize: 12.5,
                      letterSpacing: 0.4,
                      fontWeight: FontWeight.w700,
                      color: AppColors.muted)),
            ),
            SurfaceGroup(children: [
              for (final note in notes)
                _NotificationRow(note: note, onTap: () => _open(note)),
            ]),
            const SizedBox(height: 18),
          ],
      ],
    );
  }
}

/// Newest first, grouped under Today, Yesterday or the date.
List<(String, List<AppNotification>)> _byDay(List<AppNotification> notes) {
  final groups = <String, List<AppNotification>>{};
  for (final note in notes) {
    final t = note.createdAt;
    final day = DateTime(t.year, t.month, t.day);
    final label = _dayLabel(day);
    groups.putIfAbsent(label, () => []).add(note);
  }
  return [for (final e in groups.entries) (e.key, e.value)];
}

String _dayLabel(DateTime day) {
  final parsed = FlightDay.parse(day.toIso8601String());
  if (parsed == null) return '';
  if (parsed.daysAway == 0) return tr('Today').toUpperCase();
  if (parsed.daysAway == -1) return tr('Yesterday').toUpperCase();
  return parsed.shortLabel.toUpperCase();
}

String _clock(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

(IconData, ChipTone) _look(String event) => switch (event) {
      'flight_new' => (Icons.event_outlined, ChipTone.blue),
      'flight_changed' => (Icons.edit_calendar_outlined, ChipTone.amber),
      'flight_tomorrow' => (Icons.schedule_rounded, ChipTone.blue),
      'flight_departed' => (Icons.flight_takeoff_rounded, ChipTone.amber),
      'flight_soon' => (Icons.flight_land_rounded, ChipTone.amber),
      'flight_landed' => (Icons.flight_land_rounded, ChipTone.green),
      'flight_cancelled' => (Icons.cancel_outlined, ChipTone.red),
      'flight_date_passed' => (Icons.help_outline_rounded, ChipTone.red),
      'orders_received' => (Icons.inventory_2_outlined, ChipTone.green),
      'sort_waiting' => (Icons.fact_check_outlined, ChipTone.blue),
      'sort_sent_back' => (Icons.undo_rounded, ChipTone.amber),
      'sort_approved' => (Icons.check_rounded, ChipTone.green),
      'delivered' => (Icons.task_alt_rounded, ChipTone.green),
      'problem' => (Icons.warning_amber_rounded, ChipTone.red),
      _ => (Icons.notifications_none_rounded, ChipTone.neutral),
    };

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.note, required this.onTap});

  final AppNotification note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, tone) = _look(note.event);
    return Material(
      color: note.read ? Colors.transparent : const Color(0xFFF0F4FB),
      child: InkWell(
        key: Key('notification-${note.id}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            IconBadge(icon, tone: tone, size: 38, round: true),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(note.text,
                        style: TextStyle(
                            fontSize: 14,
                            height: 1.45,
                            color: AppColors.ink,
                            fontWeight:
                                note.read ? FontWeight.w400 : FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(_clock(note.createdAt),
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.muted)),
                  ]),
            ),
            if (!note.read)
              Container(
                margin: const EdgeInsets.only(left: 10, top: 6),
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                    color: AppColors.primary, shape: BoxShape.circle),
              ),
          ]),
        ),
      ),
    );
  }
}
