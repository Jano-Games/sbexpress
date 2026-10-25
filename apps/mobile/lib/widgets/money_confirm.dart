import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_colors.dart';

/// Stops a money-moving action until the operator confirms the exact effect.
Future<bool> confirmMoney(BuildContext context,
    {required String title, required String body}) async {
  final answer = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(tr('Go back'))),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(tr('Confirm')),
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
        decoration: InputDecoration(
            labelText: tr('Reason'), helperText: tr('At least 3 characters')),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(tr('Go back'))),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
          onPressed: () => Navigator.of(context).pop(controller.text.trim()),
          child: Text(tr('Confirm')),
        ),
      ],
    ),
  );
  controller.dispose();
  return answer;
}
