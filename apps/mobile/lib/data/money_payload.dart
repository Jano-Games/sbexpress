/// Two-decimal money. Zod rejects amounts that are not multiples of 0.01.
double roundMoney(double value) => double.parse(value.toStringAsFixed(2));

double? parseMoney(String text) {
  final value = double.tryParse(text.trim());
  if (value == null) return null;
  return roundMoney(value);
}

/// Empty means zero. Anything else must be a non-negative amount with at most two decimal places.
double? readOptionalMoney(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return 0;
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(trimmed)) return null;
  return roundMoney(double.parse(trimmed));
}

/// BDT is the ledger default. A CNY account sends the typed amount in CNY.
Map<String, Object?> moneyPayload(double amount, {String currency = 'BDT'}) {
  return {
    'amount': roundMoney(amount),
    if (currency != 'BDT') 'money': {'currency': currency},
  };
}
