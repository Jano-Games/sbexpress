import '../json_read.dart';

class TaskItem {
  const TaskItem({
    required this.id,
    required this.text,
    required this.auto,
    required this.done,
    required this.href,
    required this.role,
  });

  final String id;
  final String text;
  final bool auto;
  final bool done;
  final String? href;
  final String? role;

  bool get opensReview => href == '/review';

  String? get shipmentCode {
    final link = href;
    if (link == null) return null;
    final match = RegExp(r'/shipments/([^/?]+)').firstMatch(link);
    if (match == null) return null;
    return Uri.decodeComponent(match.group(1)!);
  }

  /// Auto hub steps and payment-review tasks close themselves. Manual notes toggle.
  bool get canToggle => !auto && !opensReview && !done;

  factory TaskItem.fromJson(Map<String, Object?> json) {
    return TaskItem(
      id: requiredString(json, 'id'),
      text: requiredString(json, 'text'),
      auto: requiredBool(json, 'auto'),
      done: requiredBool(json, 'done'),
      href: json.containsKey('href') ? asNullableString(json['href'], 'href') : null,
      role: json.containsKey('role') ? asNullableString(json['role'], 'role') : null,
    );
  }
}
