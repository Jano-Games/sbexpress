/// Ticket and settlement cash is stored in BDT. A CNY fund is debited or credited at the saved rate.
String bdtFundMovement({
  required double amountBdt,
  required String accountName,
  required String accountCurrency,
  required bool intoAccount,
}) {
  final amount = formatBdt(amountBdt);
  if (accountCurrency == 'BDT') {
    return intoAccount ? '$amount $accountName-এ ঢুকবে।' : '$amount $accountName থেকে যাবে।';
  }
  final direction = intoAccount ? 'ঢুকবে' : 'কাটবে';
  return '$amount $accountName-এ $direction। অঙ্কটি BDT; $accountCurrency ব্যালেন্স সেভ করা রেটে বদলাবে।';
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
  final text = '৳$grouped.${parts[1]}';
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
      return 'পেইড';
    case 'partial':
      return 'আংশিক';
    case 'unpaid':
      return 'বাকি';
    case 'cod':
      return 'COD';
    case 'monthly':
      return 'মাসিক';
    default:
      return status;
  }
}

String paymentTermsLabel(String terms) {
  switch (terms) {
    case 'invoice':
      return 'ইনভয়েস';
    case 'cod':
      return 'COD';
    case 'monthly':
      return 'মাসিক';
    default:
      return terms;
  }
}
