import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sbexpress/data/api/api_client.dart';
import 'package:sbexpress/data/session/session_store.dart';

ApiClient screenFixtureApi(
    {Future<http.Response?> Function(http.Request)? intercept}) {
  return ApiClient(
    baseUrl: 'http://localhost:3002',
    session: MemorySessionStore()..token = 'tok',
    httpClient: MockClient((request) async {
      final intercepted = await intercept?.call(request);
      if (intercepted != null) return intercepted;
      final path = request.url.path;
      if (path == '/api/flights/hub') {
        return http.Response(jsonEncode(hubScheduleBody()), 200,
            headers: {'content-type': 'application/json'});
      }
      if (path.startsWith('/api/flights/hub/')) {
        return http.Response(jsonEncode(hubFlightDetailBody()), 200,
            headers: {'content-type': 'application/json'});
      }
      if (path == '/api/flyers') {
        return http.Response(jsonEncode({'flyers': []}), 200);
      }
      if (path == '/api/suppliers/C-14') {
        return http.Response(
            jsonEncode({
              'supplier': {
                ...Map<String, Object?>.from(
                    (_customersBody()['suppliers'] as List).first as Map),
                'orders': _overviewBody()['activeShipments'],
                'payments': [],
                'invoices': [],
              }
            }),
            200);
      }
      if (path.endsWith('/media')) {
        return http.Response(
            jsonEncode({'configured': true, 'media': []}), 200);
      }
      if (path == '/api/shipments/SH-18') {
        return http.Response(
            jsonEncode({
              'shipment': {
                ...Map<String, Object?>.from(
                    (_overviewBody()['activeShipments'] as List).first as Map),
                'chargeRate': 1200,
                'chargeCurrency': 'BDT',
                'packageCount': 1,
                'packedAt': null,
                'photosCount': 0,
                'hasVideo': false,
                'serials': [],
                'pcsItems': [],
                'lastMile': null,
                'flyerName': null,
                'log': [],
                'invoice': null,
                'payments': [],
              }
            }),
            200);
      }
      final body = path == '/api/settings/setup-status'
          ? {
              'rateConfirmed': true,
              'accounts': 2,
              'paymentMethods': 1,
              'users': 2,
              'storageConfigured': true,
              'cleanupEnabled': true,
              'lastCleanupAt': null
            }
          : path == '/api/settings'
              ? {
                  'settings': {
                    'rate': 17.5,
                    'threshold': 0.5,
                    'pcsRates': {'Mobile': 2000, 'Laptop': 3500}
                  }
                }
              : path == '/api/categories'
                  ? {
                      'categories': ['General', 'Mobile', 'Laptop', 'Clothing']
                    }
                  : path == '/api/settings/pay-methods'
                      ? {
                          'methods': [
                            {
                              'id': 'm1',
                              'kind': 'mobile_wallet',
                              'provider': 'bKash',
                              'label': 'Business',
                              'number': '01XXXXXXXXX',
                              'bankName': '',
                              'accountName': '',
                              'enabled': true,
                              'currency': 'BDT'
                            },
                            {
                              'id': 'm2',
                              'kind': 'bank_account',
                              'provider': 'bank',
                              'label': '',
                              'number': '',
                              'bankName': 'Bank account',
                              'accountName': 'SBExpress',
                              'enabled': false,
                              'currency': 'CNY'
                            },
                          ]
                        }
                      : path == '/api/shipments'
                          ? {'shipments': _overviewBody()['activeShipments']}
                          : path == '/api/todos'
                              ? {
                                  'todos': [
                                    {
                                      'id': 't1',
                                      'text': 'SH-18 এর ওজন নিশ্চিত করুন',
                                      'auto': true,
                                      'done': false,
                                      'href': '/shipments/SH-18'
                                    },
                                    {
                                      'id': 't2',
                                      'text': 'নতুন পেমেন্টের রসিদ যাচাই করুন',
                                      'auto': true,
                                      'done': false,
                                      'href': '/review'
                                    },
                                    {
                                      'id': 't3',
                                      'text': 'আগামী ফ্লাইটের সময় নিশ্চিত করুন',
                                      'auto': false,
                                      'done': false
                                    },
                                  ]
                                }
                              : path == '/api/review'
                                  ? {
                                      'queue': [
                                        {
                                          'code': 'SH-18',
                                          'supplierCode': 'C-14',
                                          'supplierName': 'Nila Store',
                                          'method': 'bKash',
                                          'amount': 3500,
                                          'sourceCurrency': 'CNY',
                                          'sourceAmount': 200,
                                          'txnRef': 'TRX8264K',
                                          'date': '20 Oct 2026',
                                          'screenshot': null
                                        },
                                        {
                                          'code': 'SH-21',
                                          'supplierCode': 'C-15',
                                          'supplierName': 'Rahman Traders',
                                          'method': 'Bank transfer',
                                          'amount': 4800,
                                          'sourceCurrency': 'BDT',
                                          'sourceAmount': 4800,
                                          'txnRef': 'BANK88542',
                                          'date': '20 Oct 2026',
                                          'screenshot': null
                                        },
                                      ],
                                      'statements': []
                                    }
                                  : path.contains('/invoice')
                                      ? _invoiceBody()
                                      : path.contains('statement-links')
                                          ? _statementLinks()
                                          : path.contains('statement-receipts')
                                              ? _statementReceipts()
                                              : path.endsWith('/users')
                                                  ? _usersBody()
                                                  : path.contains(
                                                          '/reconciliation')
                                                      ? _reconciliationBody()
                                                      : path.contains(
                                                              '/activity')
                                                          ? _activityBody()
                                                          : path.contains(
                                                                  '/shipments/')
                                                              ? _costBody()
                                                              : path.contains(
                                                                      '/flights/')
                                                                  ? _flightDetail()
                                                                  : path.endsWith(
                                                                          '/hub')
                                                                      ? _hubBody()
                                                                      : path.endsWith(
                                                                              '/overview')
                                                                          ? _overviewBody()
                                                                          : path.endsWith('/flights')
                                                                              ? _flightsBody()
                                                                              : path.endsWith('/suppliers')
                                                                                  ? _customersBody()
                                                                                  : _financeBody();
      return http.Response(jsonEncode(body), 200,
          headers: {'content-type': 'application/json'});
    }),
  );
}

Map<String, Object?> _hubBody() => {
      'todayLabel': 'Tue 20 Oct 2026',
      'atHubCount': 2,
      'incoming': {
        'kg': 12.5,
        'count': 2,
        'flightCode': 'BG305-20261020-ab12cd',
        'flightDate': '2026-10-21'
      },
      'openTodoCount': 3,
      'notices': [
        {'tag': 'FLIGHT', 'text': 'BG305 arrives this evening'},
      ],
      'toProcess': [
        _shipment(code: 'SH-18', status: 'received_bd_hub', statusIndex: 5),
        _shipment(
            code: 'SH-19',
            status: 'ready_for_last_mile',
            statusIndex: 6,
            weighed: 4.2),
      ],
      'upcomingFlights': hubScheduleBody()['upcoming'],
    };

/// Hub-safe flight rows, dated relative to today so labels stay stable.
Map<String, Object?> hubScheduleBody() {
  String day(int offset) => DateTime.now()
      .add(Duration(days: offset))
      .toIso8601String()
      .substring(0, 10);
  Map<String, Object?> flight(String number, int offset,
          {required int shipments,
          required double kg,
          List<String> flyers = const ['Arif Rahman'],
          String dep = '10:40',
          String arr = '15:25',
          String status = 'upcoming',
          int received = 0}) =>
      {
        'code': '$number-${day(offset).replaceAll('-', '')}-ab12cd',
        'date': day(offset),
        'depTime': dep,
        'arrTime': arr,
        'via': 'Via KMG Kunming',
        'from': 'Chengdu',
        'to': 'Dhaka',
        'status': status,
        'statusLabel': status == 'completed' ? 'Completed' : 'Upcoming',
        'scheduleNeedsConfirmation': false,
        'flyers': flyers,
        'shipmentCount': shipments,
        'kg': kg,
        'receivedCount': received,
      };
  return {
    'upcoming': [
      flight('BG147', 2, shipments: 2, kg: 18.4),
      flight('BG152', 5, shipments: 4, kg: 26, flyers: ['Rakib Hasan']),
      flight('BG160', 9,
          shipments: 1, kg: 5.5, flyers: const [], dep: '—', arr: '—'),
    ],
    'arrived': [
      flight('BG139', -3,
          shipments: 3, kg: 12.5, status: 'completed', received: 3),
    ],
  };
}

Map<String, Object?> hubFlightDetailBody() => {
      'flight': {
        ...Map<String, Object?>.from(
            (hubScheduleBody()['upcoming'] as List).first as Map),
        'flyerDetails': [
          {'name': 'Arif Rahman', 'bdPhone': '01800000000', 'initial': 'A'},
        ],
        'shipments': [
          {
            ..._shipment(
                code: 'SH-51', status: 'ready_for_shipment', statusIndex: 2),
            'supplierName': null,
            'bookedKg': 8.2,
            'effectiveKg': 8.2,
          },
          {
            ..._shipment(
                code: 'SH-53', status: 'ready_for_shipment', statusIndex: 2),
            'supplierName': null,
            'description': 'cosmetics',
            'bookedKg': 10.2,
            'effectiveKg': 10.2,
          },
        ],
      }
    };

Map<String, Object?> _overviewBody() => {
      'weekLabel': '19 Oct – 20 Oct',
      'todayLabel': 'Tuesday 20 Oct 2026',
      'rate': 17.5,
      'cash': {'bdt': 84250, 'cny': 1200, 'worth': 105250},
      'received': 18000,
      'expenses': 6400,
      'net': 11600,
      'profit': 22000,
      'unpaid': 15400,
      'reviewCount': 2,
      'openTodoCount': 4,
      'nextFlight': {
        'code': 'BG305-20261020-ab12cd',
        'date': '2026-10-21',
        'bookedKg': 31.5,
        'spaceKg': 44
      },
      'notices': [
        {'tag': 'WEIGHT', 'text': 'SH-18 weighed 1.4 kg over the booking'},
      ],
      'flights': [],
      'activeShipmentCount': 1,
      'activeShipments': [
        {
          ..._shipment(
              code: 'SH-18', status: 'received_bd_hub', statusIndex: 5),
          'supplierName': 'Nila Store',
          'charge': 4800,
          'billAmount': 4800,
          'discountAmount': 0,
          'paidAmount': 1000,
          'dueAmount': 3800,
          'payStatus': 'partial',
          'payMethod': null,
          'paymentTerms': 'invoice',
          'freeOfCharge': false,
          'receiptStatus': null,
        },
      ],
    };

Map<String, Object?> _flightsBody() => {
      'flights': [
        {
          'code': 'BG305-20261021-ab12cd',
          'date': '2026-10-21',
          'depTime': '09:40',
          'arrTime': '12:10',
          'via': 'Direct',
          'fare': 8000,
          'actualCost': 42000,
          'agencyShare': 8000,
          'flyerDue': 34000,
          'ticketPaid': 42000,
          'ticketDue': 0,
          'spaceKg': 44,
          'mobiles': 2,
          'laptops': 1,
          'bookedKg': 31.5,
          'leftKg': 12.5,
          'status': 'upcoming',
          'statusLabel': 'Upcoming',
          'flyers': ['Arif Rahman'],
          'shipmentCount': 3,
          'revenue': 64000,
          'scheduleNeedsConfirmation': false,
          'settlements': [
            {'name': 'Arif Rahman', 'contribution': 34000, 'paidAmount': 0},
          ],
        },
      ],
    };

Map<String, Object?> _customersBody() => {
      'suppliers': [
        {
          'code': 'C-14',
          'name': 'Nila Store',
          'phone': '01700000000',
          'address': 'Bashundhara',
          'terms': 'instant',
          'orderCount': 4,
          'deliveredCount': 2,
          'shippedKg': 18.5,
          'billed': 24000,
          'paid': 8600,
          'balance': 15400,
          'creditBalance': 0,
          'pricingPending': 1,
          'discountTotal': 200,
        },
      ],
    };

Map<String, Object?> _reconciliationBody() => {
      'accounts': [
        {
          'name': 'Dhaka cash',
          'currency': 'BDT',
          'balance': 84250,
          'recordedNetMovement': 18000,
          'impliedOpeningBalance': 66250
        },
        {
          'name': 'Chengdu cash',
          'currency': 'CNY',
          'balance': 1200,
          'recordedNetMovement': 1200,
          'impliedOpeningBalance': 0
        },
      ],
      'missingPostings': [
        {'kind': 'payment', 'reference': 'Legacy deposit', 'amount': 50},
      ],
      'shipmentDifferences': [
        {
          'code': 'SH-18',
          'allocatedPaid': 1000,
          'ledgerPaid': 800,
          'difference': 200
        },
      ],
      'note':
          'Implied opening balances are derived from current balances and recorded movements.',
    };

Map<String, Object?> _activityBody() => {
      'page': 1,
      'total': 2,
      'limit': 25,
      'entries': [
        {
          'id': 'p1',
          'label': 'Payment',
          'kind': 'customer',
          'amount': 1000,
          'sourceCurrency': 'BDT',
          'sourceAmount': 1000,
          'sourceFxRate': 1,
          'at': '2026-10-20T09:30:00.000Z',
          'reference': 'SH-18 / bkash',
          'shipmentCode': 'SH-18',
          'accountName': 'Dhaka cash',
          'reason': '',
          'canReverse': true,
          'reversalKind': 'payment',
        },
        {
          'id': 'c1',
          'label': 'Credit applied',
          'kind': 'applied',
          'amount': -200,
          'sourceCurrency': 'CNY',
          'sourceAmount': 11.43,
          'sourceFxRate': 17.5,
          'at': '2026-10-19T04:00:00.000Z',
          'reference': 'advance',
          'shipmentCode': null,
          'accountName': null,
          'reason': 'Applied to bill',
          'canReverse': false,
          'reversalKind': 'credit',
        },
      ],
    };

Map<String, Object?> _financeBody() => {
      'period': 'week',
      'periodLabel': 'This week',
      'rate': 17.5,
      'cash': {'bdt': 84250, 'cny': 1200, 'worth': 105250},
      'received': 18000,
      'expenses': 6400,
      'net': 11600,
      'receivables': {'total': 15400, 'count': 3},
      'results': {
        'shipmentCount': 6,
        'billing': 64000,
        'costs': 22000,
        'profit': 42000,
        'marginPct': 65
      },
      'accounts': [
        {
          'name': 'Dhaka cash',
          'kind': 'cash',
          'currency': 'BDT',
          'balance': 84250
        },
        {
          'name': 'Chengdu cash',
          'kind': 'cash',
          'currency': 'CNY',
          'balance': 1200
        },
      ],
      'ticketPayables': 0,
      'costPayables': 1400,
      'flyerReceivables': 34000,
    };

Map<String, Object?> _shipment(
        {required String code,
        required String status,
        required int statusIndex,
        double? weighed}) =>
    {
      'code': code,
      'supplierCode': 'C-14',
      'flightCode': 'BG305-20261021-ab12cd',
      'flightDate': '2026-10-21',
      'bookedKg': 4,
      'weighedKg': weighed,
      'effectiveKg': weighed ?? 4,
      'weightDelta': null,
      'description': 'phones',
      'categories': ['mobile'],
      'status': status,
      'statusIndex': statusIndex,
      'statusLabel': status,
      'exception': null,
      'exceptionReason': '',
      'date': '2026-10-18',
    };

Map<String, Object?> _invoiceBody() => {
      'saved': true,
      'invoice': {
        'state': 'draft',
        'needsReview': false,
        'pricingMode': 'automatic',
        'number': 'INV-18',
        'lines': [
          {'label': 'Freight', 'amount': 4800},
          {'label': 'Packing', 'amount': 200},
        ],
        'discount': 200,
        'note': '',
        'total': 4800,
        'paidAmount': 1000,
        'dueAmount': 3800,
      },
    };

Map<String, Object?> _costBody() => {
      'costs': {
        'items': [
          {
            'id': 'cost-1',
            'name': 'Courier',
            'category': 'courier',
            'amount': 350,
            'paidAmount': 0,
            'dueAmount': 350,
            'costField': null,
            'voidedAt': null,
          },
        ],
        'total': 350,
        'unpaidCosts': {'cnFare': 0, 'bdFare': 0, 'customsTax': 0},
      },
    };

Map<String, Object?> _usersBody() => {
      'users': [
        {
          'id': 'u1',
          'name': 'Rafiq',
          'email': 'rafiq@sbx.test',
          'role': 'admin',
          'active': true
        },
        {
          'id': 'u2',
          'name': 'Hub desk',
          'email': 'hub@sbx.test',
          'role': 'hub',
          'active': true
        },
      ],
    };

Map<String, Object?> _statementLinks() => {
      'links': [
        {
          'id': 'link-1',
          'url': 'https://track.example/s/demo',
          'status': 'active',
          'expiresAt': '2026-10-28T00:00:00.000Z',
        },
      ],
      'balance': {'billed': 4800, 'paid': 1000, 'due': 3800},
    };

Map<String, Object?> _statementReceipts() => {
      'receipts': [
        {
          'reference': 'rcpt-1',
          'amount': 500,
          'method': 'bKash',
          'status': 'pending',
          'reason': '',
          'month': '2026-10',
        },
      ],
    };

Map<String, Object?> _flightDetail() {
  final flight = Map<String, Object?>.from(
      (_flightsBody()['flights'] as List).first as Map);
  flight['ticketDue'] = 1200;
  flight['ticketRefundDue'] = 0;
  flight['unallocatedFlyerPaid'] = 500;
  flight['flyerDetails'] = [
    {'name': 'Arif Rahman', 'bdPhone': '01800000000', 'initial': 'A'},
  ];
  flight['bookings'] = <Map<String, Object?>>[];
  return {'flight': flight};
}
