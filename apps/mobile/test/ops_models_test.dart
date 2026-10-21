import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sbexpress/data/models/customer.dart';
import 'package:sbexpress/data/models/finance_snapshot.dart';
import 'package:sbexpress/data/models/flight.dart';
import 'package:sbexpress/data/models/ledger_actions.dart';
import 'package:sbexpress/data/models/workspace.dart';
import 'package:sbexpress/data/pay_method_body.dart';
import 'package:sbexpress/data/repositories/finance_repository.dart';
import 'package:sbexpress/data/repositories/flight_repository.dart';
import 'package:sbexpress/data/repositories/shipment_repository.dart';
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
    expect(body['pricingMode'], 'automatic');
  });

  test('edited invoice keeps the discount, cost id, and manual mode', () {
    const document = InvoiceDocument(
      saved: true,
      state: 'issued',
      needsReview: false,
      pricingMode: 'manual',
      number: 'INV-1',
      lines: [InvoiceLine(label: 'Freight', amount: 1000, costId: 'cost-1'), InvoiceLine(label: 'Packing', amount: 50)],
      discount: 25,
      note: 'revised',
      total: 1025,
      paidAmount: 0,
      dueAmount: 1025,
    );
    final body = invoiceIssueBody(document, revisionReason: 'weight changed', state: 'issued', pricingMode: 'manual');
    final lines = body['lines'] as List<Map<String, Object?>>;
    expect(lines.first['costId'], 'cost-1');
    expect(lines.last.containsKey('costId'), isFalse);
    expect(body['discount'], 25);
    expect(body['pricingMode'], 'manual');
    expect(body['revisionReason'], 'weight changed');
  });

  test('flight draft posts a paying account only when one is chosen', () {
    final body = const FlightDraft(
      airlineCode: 'BG305',
      date: '2026-10-21',
      flyerNames: ['Arif'],
      spaceKg: 44,
      mobiles: 2,
      laptops: 1,
      actualCost: 42000,
      agencyShare: 8000,
      accountName: 'Dhaka cash',
    ).toJson();
    expect(body['accountName'], 'Dhaka cash');
  });

  test('pay method, transfer, and cost bodies match the ledger rules', () {
    final mobile = mobilePayMethodBody(provider: 'bKash', number: '01700000000', currency: 'BDT');
    expect(mobile['kind'], 'mobile_banking');
    expect(mobile.containsKey('qrImage'), isFalse);
    final bank = bankPayMethodBody(bankName: 'City', accountNumber: '123', accountName: 'SBX', currency: 'CNY');
    expect(bank['kind'], 'bank_account');
    expect(bank['currency'], 'CNY');
    final transfer = transferBody(from: 'Dhaka cash', to: 'Chengdu cash', amount: 10.005, note: ' float ', reference: '11111111-1111-4111-8111-111111111111', receivedAmount: 170);
    expect(transfer['amount'], 10.01);
    expect(transfer['note'], 'float');
    expect(transfer['receivedAmount'], 170);
    final later = shipmentExpenseBody(category: 'courier', amount: 12.345, currency: 'BDT', reason: 'gate', paymentTiming: 'later');
    expect(later.containsKey('accountName'), isFalse);
    expect(later['paymentTiming'], 'later');
    expect(
      () => shipmentExpenseBody(category: 'courier', amount: 10, currency: 'BDT', reason: 'pay', paymentTiming: 'later', costField: 'bdFare'),
      throwsFormatException,
    );
    final rows = contributionBody([(name: 'Arif', contribution: 10.005, legacyPaid: 0)]);
    final allocations = rows['allocations'] as List<Map<String, Object?>>;
    expect(allocations.single['contribution'], 10.01);
  });

  test('statement receipt reason and legacy cost fields parse', () {
    final receipt = StatementReceiptInfo.fromJson({
      'reference': 'r1',
      'amount': 10,
      'method': 'bKash',
      'status': 'pending',
      'reason': null,
      'month': '2026-10',
    });
    expect(receipt.reason, isEmpty);
    final item = ShipmentCostItem.fromJson({
      'id': 'bdFare',
      'name': 'BD fare',
      'category': 'courier',
      'amount': 100,
      'paidAmount': 0,
      'dueAmount': 100,
      'costField': 'bdFare',
      'voidedAt': null,
    });
    expect(item.legacyField, isTrue);
    expect(item.voided, isFalse);
  });

  test('qr data url is a jpeg payload', () {
    final bytes = Uint8List.fromList(img.encodeJpg(img.Image(width: 8, height: 8)));
    final url = jpegQrDataUrl(bytes);
    expect(url, startsWith('data:image/jpeg;base64,'));
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
