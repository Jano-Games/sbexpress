import 'package:flutter_test/flutter_test.dart';
import 'package:sbexpress/data/models/customer.dart';
import 'package:sbexpress/data/models/finance_snapshot.dart';
import 'package:sbexpress/data/models/flight.dart';
import 'package:sbexpress/data/models/workspace.dart';
import 'package:sbexpress/features/more/destinations.dart';
import 'package:sbexpress/data/models/session_user.dart';

void main() {
  test('flight code hides the internal booking suffix', () {
    expect(displayFlightCode('BG305-20261020-ab12cd'), 'BG305');
    expect(displayFlightCode('CA123+MU456'), 'CA123-MU456');
  });

  test('flight draft does not post a paying account', () {
    final body = const FlightDraft(
      airlineCode: 'BG305',
      date: '2026-10-21',
      flyerNames: ['Arif'],
      spaceKg: 44,
      mobiles: 2,
      laptops: 1,
      actualCost: 0,
      agencyShare: 0,
    ).toJson();
    expect(body.containsKey('accountName'), isFalse);
    expect(body['actualCost'], 0);
    expect(body['flyerNames'], ['Arif']);
  });

  test('intake body keeps payment terms and omits an unassigned flight', () {
    final body = const IntakeDraft(
      supplierCode: 'C-1',
      categories: ['mobile'],
      bookedKg: 0,
      chargeRate: 0,
      chargeCurrency: 'BDT',
      description: '',
      paymentTerms: 'invoice',
      pieces: [
        IntakePiece(category: 'mobile', count: 1, rate: 0, currency: 'BDT', units: [(model: 'A', serial: 'IMEI')]),
      ],
    ).toJson();
    expect(body.containsKey('flightCode'), isFalse);
    expect(body.containsKey('flyerName'), isFalse);
    expect(body['paymentTerms'], 'invoice');
    expect(body.containsKey('payMethod'), isFalse);
    expect((body['pcsItems'] as List).length, 1);
  });

  test('customer draft omits blank contact fields', () {
    expect(const CustomerDraft(name: 'Nila', terms: 'monthly').toJson().keys.toSet(), {'name', 'terms'});
  });

  test('invoice issue uses the calculated lines and does not add one', () {
    const document = InvoiceDocument(
      saved: false,
      state: 'draft',
      needsReview: false,
      pricingMode: 'automatic',
      number: 'INV-1',
      lines: [InvoiceLine(label: 'Freight', amount: 1200)],
      discount: 0,
      note: '',
      total: 1200,
      paidAmount: 0,
      dueAmount: 1200,
    );
    final body = invoiceIssueBody(document);
    final lines = body['lines'] as List<Map<String, Object?>>;
    expect(lines, [
      {'label': 'Freight', 'amount': 1200},
    ]);
    expect(body.containsKey('amount'), isFalse);
    expect(body['state'], 'issued');
  });

  test('finance snapshot reads ledger figures and rejects a missing cash field', () {
    final snapshot = FinanceSnapshot.fromJson({
      'period': 'week',
      'periodLabel': 'This week',
      'rate': 17.5,
      'cash': {'bdt': 1000, 'cny': 20, 'worth': 1350},
      'received': 500,
      'expenses': 100,
      'net': 400,
      'receivables': {'total': 80, 'count': 1},
      'results': {'shipmentCount': 2, 'billing': 900, 'costs': 300, 'profit': 600, 'marginPct': 66},
      'accounts': [
        {'name': 'Shop cash', 'kind': 'cash', 'currency': 'BDT', 'balance': 1000},
      ],
      'ticketPayables': 0,
      'costPayables': 40,
      'flyerReceivables': 10,
    });
    expect(snapshot.cash.bdt, 1000);
    expect(snapshot.accounts.single.name, 'Shop cash');
    expect(
      () => FinanceSnapshot.fromJson({
        'period': 'week',
        'periodLabel': 'This week',
        'rate': 1,
        'received': 0,
        'expenses': 0,
        'net': 0,
        'receivables': {'total': 0, 'count': 0},
        'results': {'shipmentCount': 0, 'billing': 0, 'costs': 0, 'profit': 0, 'marginPct': null},
        'accounts': [],
        'ticketPayables': 0,
        'costPayables': 0,
        'flyerReceivables': 0,
      }),
      throwsFormatException,
    );
  });

  test('hub directory still has no finance tools', () {
    final hub = moreDestinations(UserRole.hub).map((item) => item.id).toSet();
    final admin = moreGroups(UserRole.admin).expand((group) => group.ids).toSet();
    expect(hub.contains('finance'), isFalse);
    expect(hub.contains('customers'), isFalse);
    expect(admin.contains('finance'), isTrue);
    expect(admin.contains('flyers'), isTrue);
  });
}
