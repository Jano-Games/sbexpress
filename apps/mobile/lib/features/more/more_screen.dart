import 'package:flutter/material.dart';

import '../../data/models/session_user.dart';
import '../../data/session/session_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../widgets/ui.dart';
import '../customers/customers_screen.dart';
import '../finance/finance_screen.dart';
import '../flights/flights_screen.dart';
import '../flyers/flyers_screen.dart';
import '../intake/intake_screen.dart';
import '../settings/settings_screen.dart';
import '../shipments/shipment_picker_screen.dart';
import '../tasks/tasks_screen.dart';
import 'destinations.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key, required this.user, required this.session});

  final SessionUser user;
  final SessionController session;

  @override
  Widget build(BuildContext context) {
    final items = {for (final item in moreDestinations(user.role)) item.id: item};
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(pageGutter, 20, pageGutter, 28),
          children: [
            const PageHeader(title: 'আরও', subtitle: 'বাকি কাজ এখান থেকে। হাব ম্যানেজার টাকা ও কাস্টমারের নাম দেখেন না।'),
            PaperCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const BrandLockup(),
                  const SizedBox(height: 12),
                  Text(user.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(user.email, style: const TextStyle(color: AppColors.muted)),
                  const SizedBox(height: 8),
                  StatusPill(label: user.roleLabel),
                ],
              ),
            ),
            const SizedBox(height: 16),
            for (final group in moreGroups(user.role)) ...[
              SectionTitle(title: group.title),
              for (final id in group.ids) ...[
                if (items[id] != null)
                  DirectoryTile(
                    title: items[id]!.title,
                    subtitle: items[id]!.body,
                    onTap: () => openMoreDestination(context, items[id]!),
                  ),
                const SizedBox(height: 8),
              ],
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: session.logout,
              icon: const SbxIcon(SbxIconKind.logout, color: AppColors.danger),
              label: const Text('Logout'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                minimumSize: const Size(minTouchTarget, minTouchTarget),
                side: const BorderSide(color: AppColors.danger),
                textStyle: const TextStyle(fontFamily: 'HindSiliguri', fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void openMoreDestination(BuildContext context, MoreDestination item) {
  final screen = switch (item.id) {
    'intake' => const IntakeScreen(),
    'invoice-share' => const ShipmentPickerScreen(target: ShipmentPickTarget.invoice),
    'flights' => const FlightsScreen(),
    'flyers' => const FlyersScreen(),
    'customers' => const CustomersScreen(),
    'finance' => const FinanceScreen(),
    'assign' => const AssignTaskScreen(),
    'settings' => const SettingsScreen(),
    'media' => const ShipmentPickerScreen(target: ShipmentPickTarget.photos),
    'imei' => const ShipmentPickerScreen(target: ShipmentPickTarget.imei),
    _ => null,
  };
  if (screen == null) return;
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
}
