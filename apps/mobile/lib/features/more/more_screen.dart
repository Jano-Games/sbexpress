import 'package:flutter/material.dart';

import '../../data/models/session_user.dart';
import '../../app_scope.dart';
import '../admin/payment_review_screen.dart';
import '../../data/session/session_controller.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ui.dart';
import '../customers/customers_screen.dart';
import '../finance/finance_screen.dart';
import '../flights/flights_screen.dart';
import '../flyers/flyers_screen.dart';
import '../intake/intake_screen.dart';
import '../settings/settings_screen.dart';
import '../settings/staff_screen.dart';
import '../shipments/shipment_picker_screen.dart';
import '../tasks/tasks_screen.dart';
import 'destinations.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key, required this.user, required this.session});

  final SessionUser user;
  final SessionController session;

  @override
  Widget build(BuildContext context) {
    final items = {
      for (final item in moreDestinations(user.role)) item.id: item
    };
    return WorkspaceScaffold(
        root: true,
        title: tr('More'),
        subtitle: tr('Team, partners and business tools'),
        children: [
          PaperCard(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    child: Text(
                        user.name.isEmpty
                            ? 'S'
                            : user.name.characters.first.toUpperCase(),
                        style: const TextStyle(
                            fontSize: 19, fontWeight: FontWeight.w700))),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(user.name,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      Text(user.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.muted)),
                    ])),
                const SizedBox(width: 8),
                Flexible(child: StatusPill(label: user.roleLabel)),
              ])),
          const SizedBox(height: 14),
          for (final group in moreGroups(user.role)) ...[
            PaperCard(
                padding: const EdgeInsets.fromLTRB(10, 14, 10, 8),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                          padding: const EdgeInsets.only(left: 6, bottom: 6),
                          child: Text(group.title,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.muted))),
                      LayoutBuilder(
                          builder: (context, constraints) =>
                              Wrap(runSpacing: 4, children: [
                                for (final id in group.ids)
                                  if (items[id] != null)
                                    SizedBox(
                                        width: constraints.maxWidth / 4,
                                        child: Tooltip(
                                            message: items[id]!.body,
                                            child: QuickAction(
                                                label: items[id]!.title,
                                                icon: _destinationIcon(id),
                                                tone: id == 'review'
                                                    ? ChipTone.amber
                                                    : ChipTone.blue,
                                                onTap: () =>
                                                    openMoreDestination(
                                                        context, items[id]!)))),
                              ])),
                    ])),
            const SizedBox(height: 12),
          ],
          const _LanguageCard(),
          const SizedBox(height: 16),
          AppButton(
              onPressed: session.logout,
              icon: Icons.logout_rounded,
              kind: AppButtonKind.danger,
              label: tr('Log out')),
        ]);
  }
}

/// English or Bangla for this phone. Each option is written in its own
/// language so anyone can find theirs.
class _LanguageCard extends StatelessWidget {
  const _LanguageCard();

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context).language;
    return PaperCard(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          const IconBadge(Icons.translate_rounded),
          const SizedBox(width: 12),
          Expanded(
              child: Text(tr('Language'),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600))),
          ChoiceChips(
              options: const [
                (value: 'en', label: 'English'),
                (value: 'bn', label: 'বাংলা'),
              ],
              selected: appLanguage.value.name,
              onSelected: (value) {
                final language =
                    value == 'bn' ? AppLanguage.bn : AppLanguage.en;
                if (language == appLanguage.value) return;
                if (store != null) {
                  store.save(language);
                } else {
                  appLanguage.value = language;
                }
              }),
        ]));
  }
}

void openMoreDestination(BuildContext context, MoreDestination item) {
  final screen = switch (item.id) {
    'tasks' => TasksScreen(
        role: AppScope.of(context).session.user!.role,
        tasks: AppScope.of(context).tasks),
    'review' => const PaymentReviewScreen(),
    'intake' => const IntakeScreen(),
    'invoice-share' =>
      const ShipmentPickerScreen(target: ShipmentPickTarget.invoice),
    'flights' => const FlightsScreen(),
    'flyers' => const FlyersScreen(),
    'customers' => const CustomersScreen(),
    'finance' => const FinanceScreen(),
    'assign' => const AssignTaskScreen(),
    'settings' => const SettingsScreen(),
    'media' => const ShipmentPickerScreen(target: ShipmentPickTarget.photos),
    'imei' => const ShipmentPickerScreen(target: ShipmentPickTarget.imei),
    'staff-add' => const StaffCreateScreen(),
    'staff' => const StaffScreen(),
    _ => null,
  };
  if (screen == null) return;
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
}

IconData _destinationIcon(String id) => switch (id) {
      'tasks' => Icons.checklist_rounded,
      'review' => Icons.receipt_long_outlined,
      'intake' => Icons.add_box_outlined,
      'invoice-share' => Icons.description_outlined,
      'flights' => Icons.flight_takeoff_rounded,
      'flyers' => Icons.badge_outlined,
      'customers' => Icons.people_outline_rounded,
      'finance' => Icons.account_balance_wallet_outlined,
      'assign' => Icons.assignment_ind_outlined,
      'settings' => Icons.tune_rounded,
      'media' => Icons.photo_library_outlined,
      'imei' => Icons.qr_code_scanner_rounded,
      'staff-add' => Icons.person_add_alt_outlined,
      'staff' => Icons.groups_outlined,
      _ => Icons.chevron_right_rounded,
    };
