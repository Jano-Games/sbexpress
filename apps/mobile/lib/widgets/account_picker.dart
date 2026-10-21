import 'package:flutter/material.dart';

import '../data/models/finance_snapshot.dart';
import '../theme/app_colors.dart';

class AccountPicker extends StatelessWidget {
  const AccountPicker({super.key, required this.accounts, required this.selected, required this.onSelected});

  final List<FinanceAccount> accounts;
  final String? selected;
  final ValueChanged<FinanceAccount> onSelected;

  @override
  Widget build(BuildContext context) {
    if (accounts.isEmpty) {
      return const Text('রিসিভিং অ্যাকাউন্ট নেই। আগে ফাইন্যান্সে একটি ফান্ড যোগ করুন।', style: TextStyle(color: AppColors.muted, height: 1.35));
    }
    return Column(
      children: [
        for (final account in accounts) ...[
          Material(
            color: selected == account.name ? AppColors.tealSoft : AppColors.card,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () => onSelected(account),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                constraints: const BoxConstraints(minHeight: minTouchTarget),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: selected == account.name ? AppColors.teal : AppColors.line),
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(account.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                    Text(account.currency, style: const TextStyle(color: AppColors.muted)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
