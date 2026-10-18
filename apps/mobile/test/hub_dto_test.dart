import 'package:flutter_test/flutter_test.dart';
import 'package:sbexpress/data/models/dashboard.dart';
import 'package:sbexpress/data/models/shipment.dart';

Map<String, Object?> hubRow({double? weighedKg, String status = 'received_bd_hub'}) {
  return {
    'code': 'SH-1',
    'supplierCode': 'C-1',
    'supplierName': 'Karim Store',
    'flightCode': 'BG-147',
    'flightDate': '2026-10-20',
    'bookedKg': 4.5,
    'weighedKg': weighedKg,
    'effectiveKg': weighedKg ?? 4.5,
    'weightDelta': null,
    'description': 'phones',
    'categories': ['mobile'],
    'status': status,
    'statusIndex': 5,
    'statusLabel': 'Received at BD Hub',
    'exception': null,
    'exceptionReason': '',
    'date': '2026-10-18',
    'paymentTerms': 'cod',
    'freeOfCharge': true,
    'receiptStatus': 'pending',
    'charge': 1200,
    'billAmount': 1200,
    'discountAmount': 50,
    'paidAmount': 100,
    'dueAmount': 1100,
    'payStatus': 'partial',
    'payMethod': 'bKash',
    'chargeRate': 300,
    'chargeCurrency': 'BDT',
  };
}

void main() {
  test('hub list drops money and Low-2 keys even when the payload still has them', () {
    final row = OperationalShipment.fromJson(hubRow());
    final shown = row.toDisplayMap();
    expect(shown.keys.toSet().intersection(hubOmittedKeys), isEmpty);
    expect(shown.containsKey('supplierName'), isFalse);
    expect(shown['supplierCode'], 'C-1');
    expect(shown['effectiveKg'], 4.5);
    expect(row.toString(), isNot(contains('1200')));
  });

  test('hub detail shows weight, packages, courier ref and device photos, not rates', () {
    final json = {
      ...hubRow(weighedKg: 4.2),
      'packageCount': 2,
      'packedAt': '2026-10-18T10:00:00.000Z',
      'photosCount': 1,
      'hasVideo': false,
      'serials': ['IMEI1'],
      'flyerName': 'Arif',
      'lastMile': {
        'courier': 'Pathao',
        'ref': 'BD-9',
        'mode': 'courier',
        'bookedAt': null,
        'dispatchedAt': null,
        'handedOverAt': null,
      },
      'log': [
        {'actor': 'Hub', 'message': 'Weighed 4.2 kg', 'at': '2026-10-18T09:00:00.000Z'},
      ],
      'pcsItems': [
        {
          'category': 'mobile',
          'count': 2,
          'rate': 500,
          'currency': 'BDT',
          'units': [
            {'model': 'A', 'serial': 'IMEI1', 'serialPhotoRef': '11111111-1111-1111-1111-111111111111'},
            {'model': 'B', 'serial': 'IMEI2'},
          ],
        },
      ],
      'costs': null,
      'invoice': null,
      'payments': [],
      'receipt': null,
    };
    final detail = HubShipmentDetail.fromJson(json);
    final shown = detail.toDisplayMap();
    expect(shown.keys.toSet().intersection(hubOmittedKeys), isEmpty);
    expect(detail.packageCount, 2);
    expect(detail.hasCourierRef, isTrue);
    expect(detail.deviceCount, 2);
    expect(detail.devicePhotoCount, 1);
    final devices = shown['devices']! as List<Map<String, Object?>>;
    expect(devices.single.containsKey('rate'), isFalse);
    expect(devices.single.containsKey('currency'), isFalse);
  });

  test('admin detail keeps money fields and refuses a hub-shaped payload', () {
    final json = {
      ...hubRow(),
      'supplierName': 'Karim Store',
      'chargeRate': 300,
      'chargeCurrency': 'BDT',
      'packageCount': 1,
      'packedAt': null,
      'photosCount': 0,
      'hasVideo': false,
      'pcsItems': <Map<String, Object?>>[],
      'lastMile': null,
      'flyerName': null,
      'log': <Map<String, Object?>>[],
      'invoice': null,
      'payments': <Map<String, Object?>>[],
    };
    final detail = AdminShipmentDetail.fromJson(json);
    expect(detail.charge, 1200);
    expect(detail.dueAmount, 1100);
    expect(detail.paymentTerms, 'cod');
    expect(detail.freeOfCharge, isTrue);
    expect(detail.receiptStatus, 'pending');

    final hubOnly = Map<String, Object?>.from(json)..remove('charge');
    expect(() => AdminShipment.fromJson(hubOnly), throwsFormatException);
  });

  test('hub dashboard drops due notices and currency text', () {
    final dashboard = HubDashboard.fromJson({
      'todayLabel': 'Sun 18 Oct 2026',
      'atHubCount': 1,
      'incoming': {'kg': 10, 'count': 1, 'flightCode': 'BG-147', 'flightDate': '2026-10-20'},
      'openTodoCount': 2,
      'notices': [
        {'tag': 'WEIGHT', 'text': 'SH-1 weighed 5 kg vs 4 kg booked — Δ+1kg'},
        {'tag': 'DUE', 'text': 'balance ৳100 outstanding'},
        {'tag': 'FLIGHT', 'text': 'BG-147 departs Monday — ৳ left'},
        {'tag': 'FLIGHT', 'text': 'BG-147 departs Monday — 8 kg space left'},
      ],
      'toProcess': [hubRow()],
    });
    expect(dashboard.notices.map((notice) => notice.text), [
      'SH-1 weighed 5 kg vs 4 kg booked — Δ+1kg',
      'BG-147 departs Monday — 8 kg space left',
    ]);
    expect(dashboard.toProcess.single.toDisplayMap().keys.toSet().intersection(hubOmittedKeys), isEmpty);
  });
}
