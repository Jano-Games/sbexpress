import 'package:flutter/material.dart';
import '../data/models/finance_snapshot.dart';
import '../theme/app_colors.dart';

class AccountPicker extends StatelessWidget {
  const AccountPicker(
      {super.key,
      required this.accounts,
      required this.selected,
      required this.onSelected});
  final List<FinanceAccount> accounts;
  final String? selected;
  final ValueChanged<FinanceAccount> onSelected;
  @override
  Widget build(BuildContext context) {
    if (accounts.isEmpty) {
      return const Text('অ্যাকাউন্ট নেই। আগে ফাইন্যান্সে একটি ফান্ড যোগ করুন।',
          style: TextStyle(color: AppColors.muted));
    }
    final value =
        accounts.any((account) => account.name == selected) ? selected : null;
    return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: DropdownButtonFormField<String>(
            key: ValueKey(value),
            initialValue: value,
            isExpanded: true,
            hint: const Text('অ্যাকাউন্ট বেছে নিন',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: AppColors.muted)),
            decoration: const InputDecoration(
                prefixIcon:
                    Icon(Icons.account_balance_wallet_outlined, size: 20)),
            borderRadius: BorderRadius.circular(12),
            items: [
              for (final account in accounts)
                DropdownMenuItem(
                    value: account.name,
                    child: Text('${account.name} · ${account.currency}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14)))
            ],
            onChanged: (name) {
              if (name != null) {
                onSelected(
                    accounts.firstWhere((account) => account.name == name));
              }
            }));
  }
}
