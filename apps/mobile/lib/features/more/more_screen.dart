import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/models/dashboard.dart';
import '../../data/models/session_user.dart';
import '../../data/models/workspace.dart';
import '../../data/session/session_controller.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/more_parts.dart';
import '../../widgets/team_parts.dart'
    show DashedOutline, InitialsAvatar, plainNumber;
import '../../widgets/ui.dart';
import '../admin/payment_review_screen.dart';
import '../customers/customers_screen.dart';
import '../flyers/flyers_screen.dart';
import '../settings/pay_methods_screen.dart';
import '../settings/staff_screen.dart';
import '../shipments/shipment_picker_screen.dart';
import '../tasks/tasks_screen.dart';
import 'destinations.dart';
import 'more_sheets.dart';

/// One list for everything that is not on the bottom bar: people, money,
/// shipment tools, work and security, then log out.
class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key, required this.user, required this.session});

  final SessionUser user;
  final SessionController session;

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  SettingsSnapshot? _settings;
  SetupStatus? _setup;
  List<StaffAccount>? _staff;
  DashboardCounts? _counts;
  var _systemOpen = false;
  var _fingerprintBusy = false;
  String? _fingerprintError;

  bool get _admin => widget.user.role == UserRole.admin;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSession);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void didUpdateWidget(MoreScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      oldWidget.session.removeListener(_onSession);
      widget.session.addListener(_onSession);
    }
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSession);
    super.dispose();
  }

  void _onSession() {
    if (mounted) setState(() {});
  }

  /// Live figures for the tiles. Each is optional: a tile whose figure did
  /// not load keeps its plain line.
  Future<void> _load() async {
    if (!_admin) return;
    final scope = AppScope.of(context);
    Future<T?> quietly<T>(Future<T> Function() read) async {
      try {
        return await read();
      } catch (_) {
        return null;
      }
    }

    final results = await Future.wait<Object?>([
      quietly(scope.settings.current),
      quietly(scope.settings.setup),
      quietly(scope.settings.staff),
      quietly(scope.dashboard.counts),
    ]);
    if (!mounted) return;
    setState(() {
      _settings = results[0] as SettingsSnapshot? ?? _settings;
      _setup = results[1] as SetupStatus? ?? _setup;
      _staff = results[2] as List<StaffAccount>? ?? _staff;
      _counts = results[3] as DashboardCounts? ?? _counts;
    });
  }

  Future<void> _push(Widget screen) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) await _load();
  }

  Future<void> _open(String id) async {
    final scope = AppScope.of(context);
    switch (id) {
      case 'rate':
        final settings = _settings;
        if (settings == null) return;
        if (await showRateSheet(context, settings.rate) == true) await _load();
      case 'weight':
        final settings = _settings;
        if (settings == null) return;
        if (await showWeightAlertSheet(context, settings.threshold) == true) {
          await _load();
        }
      case 'system':
        setState(() => _systemOpen = !_systemOpen);
      case 'fingerprint':
        await _setFingerprint(!widget.session.fingerprintOn);
      default:
        final screen = switch (id) {
          'customers' => const CustomersScreen(),
          'flyers' => const FlyersScreen(),
          'team' => const StaffScreen(),
          'review' => const PaymentReviewScreen(),
          'pay-methods' => const PayMethodsScreen(),
          'invoice-share' =>
            const ShipmentPickerScreen(target: ShipmentPickTarget.invoice),
          'media' =>
            const ShipmentPickerScreen(target: ShipmentPickTarget.photos),
          'imei' => const ShipmentPickerScreen(target: ShipmentPickTarget.imei),
          'tasks' => TasksScreen(role: widget.user.role, tasks: scope.tasks),
          _ => null,
        };
        if (screen != null) await _push(screen);
    }
  }

  Future<void> _setFingerprint(bool on) async {
    if (_fingerprintBusy) return;
    setState(() {
      _fingerprintBusy = true;
      _fingerprintError = null;
    });
    try {
      if (on) {
        await widget.session.enableFingerprint();
      } else {
        await widget.session.disableFingerprint();
      }
    } catch (error) {
      if (mounted) setState(() => _fingerprintError = error.toString());
    } finally {
      if (mounted) setState(() => _fingerprintBusy = false);
    }
  }

  void _setLanguage(bool bangla) {
    final language = bangla ? AppLanguage.bn : AppLanguage.en;
    if (language == appLanguage.value) return;
    final store = AppScope.of(context).language;
    if (store != null) {
      store.save(language);
    } else {
      appLanguage.value = language;
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = {
      for (final item in moreDestinations(widget.user.role)) item.id: item
    };
    return WorkspaceScaffold(
        root: true,
        title: tr('More'),
        subtitle: tr("Everything that isn't on the bottom bar"),
        onRefresh: _admin ? _load : null,
        children: [
          _ProfileCard(
              user: widget.user, bangla: isBangla, onLanguage: _setLanguage),
          const SizedBox(height: 14),
          for (final group in moreGroups(widget.user.role)) ...[
            MoreGroupLabel(group.title),
            MoreCard(children: [
              for (final id in group.ids)
                if (items[id] != null) _tile(items[id]!),
              if (group.ids.contains('system') && _systemOpen && _setup != null)
                _SystemChecks(setup: _setup!),
            ]),
            if (group.ids.contains('fingerprint') &&
                _fingerprintError != null) ...[
              const SizedBox(height: 10),
              ErrorNote(
                  key: const Key('more-fingerprint-error'),
                  message: _fingerprintError!),
            ],
            const SizedBox(height: 14),
          ],
          const SizedBox(height: 2),
          AppButton(
              key: const Key('more-logout'),
              onPressed: widget.session.logout,
              icon: Icons.logout_rounded,
              kind: AppButtonKind.danger,
              label: tr('Log out')),
          if (_admin) ...[
            const SizedBox(height: 14),
            Text(tr('Flights, Finance and New shipment live on the bottom bar and the + button.'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12, height: 1.4, color: AppColors.muted)),
          ],
        ]);
  }

  Widget _tile(MoreDestination item) {
    final id = item.id;
    final settings = _settings;
    final setup = _setup;
    var subtitle = item.body;
    Widget? trailing;
    switch (id) {
      case 'team':
        final staff = _staff;
        if (staff != null) {
          final active = staff.where((person) => person.active);
          final hub = active.where((person) => person.role == 'hub').length;
          subtitle = [
            trn(active.length - hub, '{n} admin', '{n} admins'),
            trn(hub, '{n} hub manager', '{n} hub managers'),
            tr('add someone'),
          ].join(' · ');
        }
      case 'review':
        final waiting = _counts?.reviewCount ?? 0;
        if (waiting > 0) {
          trailing = StatusPill(
              label: tr('{n} waiting', {'n': waiting}), tone: ChipTone.amber);
        }
      case 'rate':
        if (settings != null) {
          subtitle = [
            tr('{rate} per ¥1', {'rate': takaRate(settings.rate)}),
            if (setup != null)
              setup.rateConfirmed ? tr('Confirmed') : tr('Not confirmed'),
          ].join(' · ');
          trailing = TileAction(tr('Change'));
        }
      case 'weight':
        if (settings != null) {
          final kg = plainNumber(settings.threshold);
          subtitle =
              tr('Warn when weighed is {kg} kg off the booking', {'kg': kg});
          trailing = TileAction('$kg kg');
        }
      case 'tasks':
        final open = _counts?.openTodoCount;
        if (open != null) {
          subtitle = tr('{n} open · assign hub tasks inside', {'n': open});
        }
      case 'fingerprint':
        trailing = _fingerprintBusy
            ? const SizedBox(
                width: 48,
                height: 24,
                child: Center(
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))))
            : Semantics(
                label: item.title,
                child: Switch(
                    key: const Key('more-fingerprint-switch'),
                    value: widget.session.fingerprintOn,
                    onChanged: _setFingerprint));
      case 'system':
        if (setup != null) {
          final checks = setupChecks(setup);
          final done = checks.where((check) => check.ok).length;
          final all = done == checks.length;
          subtitle = all
              ? tr('Storage, rate and accounts are set up')
              : tr('{done} of {total} set up',
                  {'done': done, 'total': checks.length});
          trailing = Row(mainAxisSize: MainAxisSize.min, children: [
            StatusPill(
                label: all ? tr('All good') : '$done / ${checks.length}',
                tone: all ? ChipTone.green : ChipTone.amber),
            Icon(
                _systemOpen
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 22,
                color: AppColors.muted),
          ]);
        }
    }
    final opens = switch (id) {
      // The sheets need today's figures; the checklist needs the status.
      'rate' || 'weight' => settings != null,
      'system' => setup != null,
      _ => true,
    };
    return Semantics(
        key: ValueKey('more-$id'),
        expanded: id == 'system' && setup != null ? _systemOpen : null,
        child: MoreTile(
            icon: _icon(id),
            tone: _tone(id),
            title: item.title,
            subtitle: subtitle,
            trailing: trailing,
            onTap: opens ? () => _open(id) : null));
  }
}

IconData _icon(String id) => switch (id) {
      'customers' => Icons.storefront_outlined,
      'flyers' => Icons.person_outline_rounded,
      'team' => Icons.groups_outlined,
      'review' => Icons.fact_check_outlined,
      'pay-methods' => Icons.credit_card_rounded,
      'rate' => Icons.swap_horiz_rounded,
      'invoice-share' => Icons.description_outlined,
      'media' => Icons.photo_outlined,
      'imei' => Icons.qr_code_scanner_rounded,
      'weight' => Icons.balance_rounded,
      'tasks' => Icons.checklist_rounded,
      'fingerprint' => Icons.fingerprint_rounded,
      'system' => Icons.verified_user_outlined,
      _ => Icons.chevron_right_rounded,
    };

ToneColors _tone(String id) => switch (id) {
      'customers' || 'rate' => MoreTone.blue,
      'flyers' => MoreTone.teal,
      'team' => MoreTone.purple,
      'review' => MoreTone.orange,
      'pay-methods' || 'system' => MoreTone.green,
      'fingerprint' => MoreTone.primary,
      _ => MoreTone.grey,
    };

/// The person signed in, with the language switch.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard(
      {required this.user, required this.bangla, required this.onLanguage});
  final SessionUser user;
  final bool bangla;
  final ValueChanged<bool> onLanguage;

  @override
  Widget build(BuildContext context) => PaperCard(
      padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
      child: Row(children: [
        InitialsAvatar(user.name.isEmpty ? 'S' : user.name,
            size: 48, letters: 1),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(user.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 16, height: 1.35, fontWeight: FontWeight.w700)),
          Text(
              '${user.isAdmin ? tr('Admin') : tr('Hub manager')} · ${user.email}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12, height: 1.4, color: AppColors.muted)),
        ])),
        const SizedBox(width: 8),
        LanguageSwitch(bangla: bangla, onChanged: onLanguage),
      ]));
}

typedef SetupCheck = ({String label, String value, bool ok});

/// What the system check looks at, in order.
List<SetupCheck> setupChecks(SetupStatus setup) => [
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
      (label: tr('Active staff'), value: '${setup.users}', ok: setup.users > 0),
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

/// The system checklist under the System check tile, two to a row.
class _SystemChecks extends StatelessWidget {
  const _SystemChecks({required this.setup});
  final SetupStatus setup;

  @override
  Widget build(BuildContext context) {
    final checks = setupChecks(setup);
    final done = checks.where((check) => check.ok).length;
    return Padding(
        key: const Key('more-system-checks'),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ExcludeSemantics(
              child: StepBars(
                  done: done, total: checks.length, current: false, height: 6)),
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
            Text(tr('Last cleanup {at}', {'at': setup.lastCleanupAt}),
                style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ],
        ]));
  }
}

class _CheckTile extends StatelessWidget {
  const _CheckTile({required this.check});
  final SetupCheck check;

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
