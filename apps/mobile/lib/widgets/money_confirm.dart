import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Stops a money-moving action until the operator confirms the exact effect.
Future<bool> confirmMoney(BuildContext context, {required String title, required String body}) async {
  final answer = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('ফিরে যান')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('নিশ্চিত'),
        ),
      ],
    ),
  );
  return answer ?? false;
}

/// Returns a reason of at least 3 characters, empty when too short, or null when cancelled.
Future<String?> askReason(BuildContext context, {required String title}) async {
  final controller = TextEditingController();
  final answer = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        maxLength: 200,
        decoration: const InputDecoration(labelText: 'কারণ', helperText: 'কমপক্ষে ৩ অক্ষর'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('ফিরে যান')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
          onPressed: () => Navigator.of(context).pop(controller.text.trim()),
          child: const Text('নিশ্চিত'),
        ),
      ],
    ),
  );
  controller.dispose();
  return answer;
}
