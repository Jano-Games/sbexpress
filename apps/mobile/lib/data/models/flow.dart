import '../json_read.dart';

/// The four costs almost every shipment has, in checklist order.
const usualCostKeys = ['packaging', 'courier', 'customs', 'transport'];

/// What is recorded so far for one usual cost; 0 means it is not added yet.
class UsualCost {
  const UsualCost(this.category, this.amount);

  final String category;
  final double amount;

  bool get added => amount > 0;

  factory UsualCost.fromJson(Map<String, Object?> json) => UsualCost(
      requiredString(json, 'category'), requiredDouble(json, 'amount'));
}

/// The usual costs under [key], or null when the server does not send them.
List<UsualCost>? optionalUsualCosts(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  return [for (final row in asMapList(value, key)) UsualCost.fromJson(row)];
}

int usualCostsAdded(List<UsualCost> costs) =>
    costs.where((cost) => cost.added).length;

/// The usual amount of each everyday cost, BDT; 0 means no suggestion.
class CostDefaults {
  const CostDefaults(
      {this.packaging = 0,
      this.courier = 0,
      this.customs = 0,
      this.transport = 0});

  final double packaging, courier, customs, transport;

  double of(String category) => switch (category) {
        'packaging' => packaging,
        'courier' => courier,
        'customs' => customs,
        'transport' => transport,
        _ => 0,
      };

  CostDefaults withValue(String category, double value) => CostDefaults(
      packaging: category == 'packaging' ? value : packaging,
      courier: category == 'courier' ? value : courier,
      customs: category == 'customs' ? value : customs,
      transport: category == 'transport' ? value : transport);

  Map<String, Object?> toJson() => {
        for (final key in usualCostKeys) key: of(key),
      };

  factory CostDefaults.fromJson(Map<String, Object?> json) => CostDefaults(
      packaging: optionalDouble(json, 'packaging') ?? 0,
      courier: optionalDouble(json, 'courier') ?? 0,
      customs: optionalDouble(json, 'customs') ?? 0,
      transport: optionalDouble(json, 'transport') ?? 0);
}

/// Money still to collect, as the overview sums it.
class CollectSummary {
  const CollectSummary({
    required this.afterDeliveryDue,
    required this.afterDeliveryCount,
    required this.overdueCount,
    required this.monthlyDue,
    required this.monthlyCustomers,
    required this.month,
    required this.monthLabel,
  });

  final double afterDeliveryDue;
  final int afterDeliveryCount;
  final int overdueCount;
  final double monthlyDue;
  final int monthlyCustomers;

  /// `YYYY-MM`.
  final String month;
  final String monthLabel;

  double get total => afterDeliveryDue + monthlyDue;

  factory CollectSummary.fromJson(Map<String, Object?> json) => CollectSummary(
        afterDeliveryDue: requiredDouble(json, 'afterDeliveryDue'),
        afterDeliveryCount: requiredInt(json, 'afterDeliveryCount'),
        overdueCount: requiredInt(json, 'overdueCount'),
        monthlyDue: requiredDouble(json, 'monthlyDue'),
        monthlyCustomers: requiredInt(json, 'monthlyCustomers'),
        month: requiredString(json, 'month'),
        monthLabel: requiredString(json, 'monthLabel'),
      );
}

/// An after-delivery shipment that was handed over and is not fully paid.
class HandedOverBill {
  const HandedOverBill({
    required this.code,
    required this.supplierCode,
    required this.supplierName,
    required this.supplierPhone,
    required this.amount,
    required this.deliveredOn,
    required this.days,
    required this.overdue,
  });

  final String code;
  final String supplierCode;
  final String supplierName;
  final String supplierPhone;
  final double amount;

  /// `YYYY-MM-DD`.
  final String deliveredOn;
  final int days;
  final bool overdue;

  factory HandedOverBill.fromJson(Map<String, Object?> json) => HandedOverBill(
        code: requiredString(json, 'code'),
        supplierCode: requiredString(json, 'supplierCode'),
        supplierName: requiredString(json, 'supplierName'),
        supplierPhone: json['supplierPhone'] is String
            ? json['supplierPhone']! as String
            : '',
        amount: requiredDouble(json, 'amount'),
        deliveredOn: requiredString(json, 'deliveredOn'),
        days: requiredInt(json, 'days'),
        overdue: requiredBool(json, 'overdue'),
      );
}

/// An after-delivery shipment on its way to the customer; due once handed over.
class ComingSoonBill {
  const ComingSoonBill({
    required this.code,
    required this.supplierCode,
    required this.supplierName,
    required this.amount,
    required this.status,
    required this.statusLabel,
  });

  final String code;
  final String supplierCode;
  final String supplierName;
  final double amount;
  final String status;
  final String statusLabel;

  factory ComingSoonBill.fromJson(Map<String, Object?> json) => ComingSoonBill(
        code: requiredString(json, 'code'),
        supplierCode: requiredString(json, 'supplierCode'),
        supplierName: requiredString(json, 'supplierName'),
        amount: requiredDouble(json, 'amount'),
        status: requiredString(json, 'status'),
        statusLabel: requiredString(json, 'statusLabel'),
      );
}

/// One monthly customer's bill for the month.
class MonthlyBill {
  const MonthlyBill({
    required this.code,
    required this.name,
    required this.phone,
    required this.billed,
    required this.paid,
    required this.due,
    required this.shipments,
    required this.linkSentOn,
    required this.linkActive,
  });

  final String code;
  final String name;
  final String phone;
  final double billed;
  final double paid;
  final double due;
  final int shipments;

  /// `YYYY-MM-DD` of the newest statement link, or null when none was sent.
  final String? linkSentOn;
  final bool linkActive;

  factory MonthlyBill.fromJson(Map<String, Object?> json) => MonthlyBill(
        code: requiredString(json, 'code'),
        name: requiredString(json, 'name'),
        phone: json['phone'] is String ? json['phone']! as String : '',
        billed: requiredDouble(json, 'billed'),
        paid: requiredDouble(json, 'paid'),
        due: requiredDouble(json, 'due'),
        shipments: requiredInt(json, 'shipments'),
        linkSentOn: requiredNullableString(json, 'linkSentOn'),
        linkActive: requiredBool(json, 'linkActive'),
      );
}

/// `GET /api/dashboard/collect`: who to collect from now, and this month's
/// monthly bills.
class CollectSheet {
  const CollectSheet({
    required this.today,
    required this.handedOver,
    required this.comingSoon,
    required this.afterDeliveryDue,
    required this.overdueCount,
    required this.month,
    required this.monthLabel,
    required this.monthly,
    required this.monthlyDue,
  });

  final String today;
  final List<HandedOverBill> handedOver;
  final List<ComingSoonBill> comingSoon;
  final double afterDeliveryDue;
  final int overdueCount;
  final String month;
  final String monthLabel;
  final List<MonthlyBill> monthly;
  final double monthlyDue;

  /// Monthly customers who still owe something this month.
  int get monthlyOwing => monthly.where((row) => row.due > 0).length;

  factory CollectSheet.fromJson(Map<String, Object?> json) {
    final after = asJsonMap(json['afterDelivery'], 'afterDelivery');
    final monthly = asJsonMap(json['monthly'], 'monthly');
    return CollectSheet(
      today: requiredString(json, 'today'),
      handedOver: [
        for (final row in requiredMapList(after, 'handedOver'))
          HandedOverBill.fromJson(row)
      ],
      comingSoon: [
        for (final row in requiredMapList(after, 'comingSoon'))
          ComingSoonBill.fromJson(row)
      ],
      afterDeliveryDue: requiredDouble(after, 'due'),
      overdueCount: requiredInt(after, 'overdueCount'),
      month: requiredString(monthly, 'month'),
      monthLabel: requiredString(monthly, 'monthLabel'),
      monthly: [
        for (final row in requiredMapList(monthly, 'customers'))
          MonthlyBill.fromJson(row)
      ],
      monthlyDue: requiredDouble(monthly, 'due'),
    );
  }
}
