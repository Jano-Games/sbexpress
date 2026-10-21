import '../json_read.dart';

class CashPosition {
  const CashPosition({required this.bdt, required this.cny, required this.worth});

  final double bdt;
  final double cny;
  final double worth;

  factory CashPosition.fromJson(Map<String, Object?> json) {
    return CashPosition(
      bdt: requiredDouble(json, 'bdt'),
      cny: requiredDouble(json, 'cny'),
      worth: requiredDouble(json, 'worth'),
    );
  }
}

class FinanceResults {
  const FinanceResults({
    required this.shipmentCount,
    required this.billing,
    required this.costs,
    required this.profit,
    required this.marginPct,
  });

  final int shipmentCount;
  final double billing;
  final double costs;
  final double profit;
  final double? marginPct;

  factory FinanceResults.fromJson(Map<String, Object?> json) {
    return FinanceResults(
      shipmentCount: requiredInt(json, 'shipmentCount'),
      billing: requiredDouble(json, 'billing'),
      costs: requiredDouble(json, 'costs'),
      profit: requiredDouble(json, 'profit'),
      marginPct: requiredNullableDouble(json, 'marginPct'),
    );
  }
}

class FinanceAccount {
  const FinanceAccount({required this.name, required this.kind, required this.currency, required this.balance});

  final String name;
  final String kind;
  final String currency;
  final double balance;

  factory FinanceAccount.fromJson(Map<String, Object?> json) {
    return FinanceAccount(
      name: requiredString(json, 'name'),
      kind: requiredString(json, 'kind'),
      currency: requiredString(json, 'currency'),
      balance: requiredDouble(json, 'balance'),
    );
  }
}

class Receivables {
  const Receivables({required this.total, required this.count});

  final double total;
  final int count;

  factory Receivables.fromJson(Map<String, Object?> json) {
    return Receivables(total: requiredDouble(json, 'total'), count: requiredInt(json, 'count'));
  }
}

/// Read-only money snapshot. Account names and balances come from the ledger.
class FinanceSnapshot {
  const FinanceSnapshot({
    required this.period,
    required this.periodLabel,
    required this.rate,
    required this.cash,
    required this.received,
    required this.expenses,
    required this.net,
    required this.receivables,
    required this.results,
    required this.accounts,
    required this.ticketPayables,
    required this.costPayables,
    required this.flyerReceivables,
  });

  final String period;
  final String periodLabel;
  final double rate;
  final CashPosition cash;
  final double received;
  final double expenses;
  final double net;
  final Receivables receivables;
  final FinanceResults results;
  final List<FinanceAccount> accounts;
  final double ticketPayables;
  final double costPayables;
  final double flyerReceivables;

  factory FinanceSnapshot.fromJson(Map<String, Object?> json) {
    return FinanceSnapshot(
      period: requiredString(json, 'period'),
      periodLabel: requiredString(json, 'periodLabel'),
      rate: requiredDouble(json, 'rate'),
      cash: CashPosition.fromJson(asJsonMap(json['cash'], 'cash')),
      received: requiredDouble(json, 'received'),
      expenses: requiredDouble(json, 'expenses'),
      net: requiredDouble(json, 'net'),
      receivables: Receivables.fromJson(asJsonMap(json['receivables'], 'receivables')),
      results: FinanceResults.fromJson(asJsonMap(json['results'], 'results')),
      accounts: [for (final row in requiredMapList(json, 'accounts')) FinanceAccount.fromJson(row)],
      ticketPayables: requiredDouble(json, 'ticketPayables'),
      costPayables: requiredDouble(json, 'costPayables'),
      flyerReceivables: requiredDouble(json, 'flyerReceivables'),
    );
  }
}
