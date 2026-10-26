import '../json_read.dart';

/// One line of `GET /api/finance/ledger`. A transfer gives two lines with the
/// same [recordId]: money out of one account and money into the other.
class LedgerLine {
  const LedgerLine({
    required this.recordId,
    required this.reversalKind,
    required this.canReverse,
    required this.key,
    required this.at,
    required this.type,
    required this.description,
    required this.reference,
    required this.account,
    required this.currency,
    required this.amount,
    this.reversedAt,
    this.reversalOfId,
    this.shipmentCode,
    this.flightCode,
    this.supplierCode,
  });

  final String recordId;
  final String reversalKind;
  final bool canReverse;
  final String key;
  final String at;

  /// customer, flyer, income, capital, customer-credit, expense, refund or
  /// transfer.
  final String type;
  final String description;

  /// The category for expenses, otherwise the payment reference.
  final String reference;
  final String? account;
  final String currency;

  /// In the account's currency; negative when money leaves the account.
  final double amount;
  final String? reversedAt;
  final String? reversalOfId;
  final String? shipmentCode;
  final String? flightCode;
  final String? supplierCode;

  /// This line undoes an earlier one.
  bool get isReversal => reversalOfId != null;

  /// An earlier line that has been undone.
  bool get isReversed => reversedAt != null;

  bool get isTransfer => type == 'transfer';

  factory LedgerLine.fromJson(Map<String, Object?> json) {
    String? optional(String key) =>
        json[key] == null ? null : requiredString(json, key);
    final recordId = requiredString(json, 'recordId');
    final reversalKind = requiredString(json, 'reversalKind');
    final amount = requiredDouble(json, 'amount');
    return LedgerLine(
      recordId: recordId,
      reversalKind: reversalKind,
      canReverse: requiredBool(json, 'canReverse'),
      key: optional('key') ?? '$reversalKind:$recordId:$amount',
      at: requiredString(json, 'at'),
      type: optional('type') ?? reversalKind,
      description: requiredString(json, 'description'),
      reference: optional('reference') ?? '',
      account: requiredNullableString(json, 'account'),
      currency: requiredString(json, 'currency'),
      amount: amount,
      reversedAt: optional('reversedAt'),
      reversalOfId: optional('reversalOfId'),
      shipmentCode: optional('shipmentCode'),
      flightCode: optional('flightCode'),
      supplierCode: optional('supplierCode'),
    );
  }
}

/// Money in and out of the filtered lines in one currency.
class LedgerTotal {
  const LedgerTotal(
      {required this.currency, required this.moneyIn, required this.moneyOut});

  final String currency;
  final double moneyIn;
  final double moneyOut;

  factory LedgerTotal.fromJson(Map<String, Object?> json) => LedgerTotal(
        currency: requiredString(json, 'currency'),
        moneyIn: requiredDouble(json, 'moneyIn'),
        moneyOut: requiredDouble(json, 'moneyOut'),
      );
}

class LedgerPage {
  const LedgerPage({
    required this.entries,
    required this.total,
    required this.page,
    required this.limit,
    required this.totals,
  });

  final List<LedgerLine> entries;

  /// Lines matching the filters, across all pages.
  final int total;
  final int page;
  final int limit;
  final List<LedgerTotal> totals;

  int get pages => total <= 0 || limit <= 0 ? 1 : (total / limit).ceil();
  bool get hasPrevious => page > 1;
  bool get hasNext => page < pages;

  LedgerTotal totalFor(String currency) {
    for (final row in totals) {
      if (row.currency == currency) return row;
    }
    return LedgerTotal(currency: currency, moneyIn: 0, moneyOut: 0);
  }

  factory LedgerPage.fromJson(Map<String, Object?> json) => LedgerPage(
        entries: [
          for (final row in requiredMapList(json, 'entries'))
            LedgerLine.fromJson(row)
        ],
        total: requiredInt(json, 'total'),
        page: requiredInt(json, 'page'),
        limit: requiredInt(json, 'limit'),
        totals: json['totals'] == null
            ? const []
            : [
                for (final row in requiredMapList(json, 'totals'))
                  LedgerTotal.fromJson(row)
              ],
      );
}

/// Ledger types the backend filters on, in menu order.
const ledgerTypes = [
  'customer',
  'customer-credit',
  'flyer',
  'income',
  'capital',
  'expense',
  'refund',
  'transfer',
];

/// Account filter value for lines that have no account.
const ledgerNoAccount = '__unassigned';

/// What the ledger screen asks for. [period] is `all`, `week` or `YYYY-MM`.
class LedgerFilter {
  const LedgerFilter({
    this.period = 'all',
    this.account,
    this.type = 'all',
    this.search = '',
    this.page = 1,
    this.limit = 25,
  });

  final String period;
  final String? account;
  final String type;
  final String search;
  final int page;
  final int limit;

  Map<String, String> get query => {
        'period': period,
        if (account != null) 'account': account!,
        'type': type,
        if (search.trim().isNotEmpty) 'search': search.trim(),
        'page': '$page',
        'limit': '$limit',
      };

  LedgerFilter copyWith({
    String? period,
    String? account,
    bool clearAccount = false,
    String? type,
    String? search,
    int? page,
  }) =>
      LedgerFilter(
        period: period ?? this.period,
        account: clearAccount ? null : account ?? this.account,
        type: type ?? this.type,
        search: search ?? this.search,
        page: page ?? this.page,
        limit: limit,
      );
}
