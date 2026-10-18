import 'package:flutter/material.dart';

import '../../data/models/session_user.dart';
import '../../data/session/session_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../widgets/ui.dart';
import 'destinations.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key, required this.user, required this.session});

  final SessionUser user;
  final SessionController session;

  @override
  Widget build(BuildContext context) {
    final items = moreDestinations(user.role);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          children: [
            const Text('আরও', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            PaperCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(user.email, style: const TextStyle(color: AppColors.muted)),
                  const SizedBox(height: 8),
                  StatusPill(label: user.roleLabel),
                ],
              ),
            ),
            const SizedBox(height: 16),
            for (final item in items) ...[
              _MoreTile(item: item, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StubScreen(destination: item)))),
              const SizedBox(height: 8),
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

class _MoreTile extends StatelessWidget {
  const _MoreTile({required this.item, required this.onTap});

  final MoreDestination item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(cardRadius),
        child: Container(
          constraints: const BoxConstraints(minHeight: minTouchTarget),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(cardRadius), border: Border.all(color: AppColors.line)),
          child: Row(
            children: [
              Expanded(child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16))),
              const Text('পরে', style: TextStyle(color: AppColors.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

class StubScreen extends StatelessWidget {
  const StubScreen({super.key, required this.destination});

  final MoreDestination destination;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BackTitle(title: destination.title),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          EmptyNote(title: 'এই স্ক্রিন এই স্লাইসে নেই', body: destination.body),
        ],
      ),
    );
  }
}
