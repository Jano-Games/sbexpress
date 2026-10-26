import '../../l10n/l10n.dart';

/// Ticket and settlement cash is stored in BDT. A CNY fund is debited or credited at the saved rate.
String bdtFundMovement({
  required double amountBdt,
  required String accountName,
  required String accountCurrency,
  required bool intoAccount,
}) {
  final amount = formatBdt(amountBdt);
  final args = {
    'amount': amount,
    'account': accountName,
    'currency': accountCurrency,
  };
  if (accountCurrency == 'BDT') {
    return intoAccount
        ? tr('{amount} goes into {account}.', args)
        : tr('{amount} goes out of {account}.', args);
  }
  return intoAccount
      ? tr(
          '{amount} goes into {account}. The amount is in BDT; the {currency} balance changes at the saved rate.',
          args)
      : tr(
          '{amount} is deducted from {account}. The amount is in BDT; the {currency} balance changes at the saved rate.',
          args);
}

String formatMoney(double value, String currency) {
  if (currency == 'CNY') {
    final negative = value < 0;
    final text = '¥${value.abs().toStringAsFixed(2)}';
    return negative ? '-$text' : text;
  }
  return formatBdt(value);
}

String formatBdt(double value) {
  final negative = value < 0;
  final fixed = value.abs().toStringAsFixed(2);
  final parts = fixed.split('.');
  final grouped = _groupIn(parts[0]);
  final text = '\u09F3$grouped.${parts[1]}';
  return negative ? '-$text' : text;
}

String _groupIn(String digits) {
  if (digits.length <= 3) return digits;
  final last3 = digits.substring(digits.length - 3);
  var rest = digits.substring(0, digits.length - 3);
  final groups = <String>[];
  while (rest.length > 2) {
    groups.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) groups.insert(0, rest);
  return '${groups.join(',')},$last3';
}

String payStatusLabel(String status) {
  switch (status) {
    case 'paid':
      return tr('Paid');
    case 'partial':
      return tr('Partial');
    case 'unpaid':
      return tr('Unpaid');
    case 'cod':
      return 'COD';
    case 'monthly':
      return tr('Monthly');
    default:
      return status;
  }
}

/// Customers pay after delivery or monthly. Old `cod` bookings are collected
/// after delivery too.
String paymentTermsLabel(String terms) {
  switch (terms) {
    case 'invoice':
    case 'cod':
      return tr('After delivery');
    case 'monthly':
      return tr('Monthly');
    default:
      return terms;
  }
}
