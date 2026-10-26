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
      if (request.method == 'POST' && path == '/api/flights/ticket') {
        return http.Response(jsonEncode(ticketImportBody()), 200,
            headers: {'content-type': 'application/json'});
      }
      if (path.startsWith('/api/flights/hub/')) {
        return http.Response(jsonEncode(hubFlightDetailBody()), 200,
            headers: {'content-type': 'application/json'});
      }
      if (path == '/api/flyers') {
        return http.Response(jsonEncode({'flyers': []}), 200);
      }
      if (path == '/api/suppliers/next-code') {
        return http.Response(jsonEncode({'code': 'C-15'}), 200,
            headers: {'content-type': 'application/json'});
      }
      if (path == '/api/finance/ledger') {
        return http.Response(jsonEncode(ledgerBody()), 200,
            headers: {'content-type': 'application/json'});
      }
      if (path == '/api/suppliers/C-14/credits') {
        return http.Response(
            jsonEncode({'balance': 1200, 'entries': [], 'refunds': []}), 200,
            headers: {'content-type': 'application/json'});
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
      if (path == '/api/dashboard/collect') {
        return http.Response(jsonEncode(collectBody()), 200,
            headers: {'content-type': 'application/json'});
      }
      if (path == '/api/dashboard/counts') {
        return http.Response(
            jsonEncode({'reviewCount': 2, 'openTodoCount': 4}), 200,
            headers: {'content-type': 'application/json'});
      }
      if (path == '/api/flights/$flowFlightCode') {
        return http.Response(jsonEncode(flowFlightDetailBody()), 200,
            headers: {'content-type': 'application/json'});
      }
      if (path == '/api/flights/BG305-20261021-ab12cd') {
        return http.Response(jsonEncode(_flightDetailFull()), 200,
            headers: {'content-type': 'application/json'});
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
                'payments': [
                  {
                    'method': 'bKash',
                    'amount': 1000,
                    'at': '2026-10-17T10:00:00.000Z',
                    'reference': ''
                  },
                ],
                'costs': {
                  'items': [],
                  'usualCosts': _usual(150, 0, 400, 120),
                  'total': 670,
                },
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
                    'pcsRates': {'Mobile': 2000, 'Laptop': 3500},
                    'costDefaults': {
                      'packaging': 150,
                      'courier': 300,
                      'customs': 400,
                      'transport': 120
                    },
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

Map<String, Object?> _ticketLeg(String code, String date, String from,
        String fromCity, String to, String toCity, String dep, String arr) =>
    {
      'source': 'ticket',
      'code': code,
      'airline': 'China Eastern Airlines',
      'date': date,
      'arrDate': date,
      'fromIata': from,
      'fromCity': fromCity,
      'toIata': to,
      'toCity': toCity,
      'depTime': dep,
      'arrTime': arr,
      'status': 'Confirmed',
    };

/// A read return ticket; the passenger and numbers are made up.
Map<String, Object?> ticketImportBody() => {
      'ticket': {
        'agency': 'DESH TRAVELER',
        'passenger': 'KHAN / MD ARIF HOSSAIN SD',
        'pnr': 'TEST01',
        'ticketNumber': '781-0000000001',
        'issuedOn': '2026-10-24',
      },
      'flyerMatches': [
        {'name': 'Arif Rahman', 'score': 1},
      ],
      'journeys': [
        {
          'direction': 'to_bangladesh',
          'date': '2026-11-13',
          'legs': [
            _ticketLeg('MU5842', '2026-11-13', 'TFU', 'Chengdu', 'KMG',
                'Kunming', '21:00', '22:30'),
            _ticketLeg('MU2035', '2026-11-14', 'KMG', 'Kunming', 'DAC', 'Dhaka',
                '12:10', '13:00'),
          ],
        },
        {
          'direction': 'from_bangladesh',
          'date': '2026-11-23',
          'legs': [
            _ticketLeg('MU2036', '2026-11-23', 'DAC', 'Dhaka', 'KMG', 'Kunming',
                '14:00', '18:20'),
            _ticketLeg('MU5843', '2026-11-24', 'KMG', 'Kunming', 'CTU',
                'Chengdu', '08:40', '10:05'),
          ],
        },
      ],
    };

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
        // As the server words them, so the overview can read them.
        {
          'tag': 'WEIGHT',
          'text':
              'SH-48 (C-15 · Rahman Traders) weighed 6.2 kg vs 5.6 kg booked — Δ+0.6kg'
        },
        {
          'tag': 'FLIGHT',
          'text':
              '$flowFlightCode departs Thursday 29 Oct — 12.5 kg space left. Flyer: Arif Rahman, Rakib Hasan'
        },
        {
          'tag': 'DUE',
          'text':
              'Billing cycle closes 31 Oct — Nila Store (C-14) balance ৳15,400 outstanding'
        },
      ],
      'flyerReceivables': 9000,
      'payables': 14200,
      'stageCounts': {
        'pending': 1,
        'received_cn_hub': 1,
        'ready_for_shipment': 0,
        'in_transit': 1,
        'customs_cleared': 0,
        'received_bd_hub': 1,
        'ready_for_last_mile': 1,
        'out_for_delivery': 2,
        'delivered': 4,
      },
      // Newest first; five in all, so two more than the home lists.
      'flyersMissingDocs': [
        {
          'name': 'Md Rifat Shahriar',
          'missing': ['visa', 'admission']
        },
        {
          'name': 'Nusrat Jahan',
          'missing': ['student_id']
        },
        {
          'name': 'Tanvir Ahmed',
          'missing': ['student_id', 'visa', 'admission']
        },
        {
          'name': 'Farhan Kabir',
          'missing': ['visa']
        },
      ],
      'flyersMissingDocsCount': 5,
      'flights': [
        {
          'code': flowFlightCode,
          'date': _fixtureDay(3),
          'flyers': ['Arif Rahman', 'Rakib Hasan'],
          'bookedKg': 31.5,
          'spaceKg': 44,
          'status': 'upcoming',
          'shipmentCount': 4,
          'revenue': 31800,
          'costs': 3620,
          'profit': 16180,
          'missingCostCount': 2,
        },
        {
          'code': 'BG147-${_fixtureDay(9).replaceAll('-', '')}-cd9',
          'date': _fixtureDay(9),
          'flyers': ['Sumi Akter'],
          'bookedKg': 18.4,
          'spaceKg': 40,
          'status': 'upcoming',
          'shipmentCount': 2,
          'revenue': 17480,
          'costs': 0,
          'profit': 11480,
          'missingCostCount': 0,
        },
        {
          'code': 'BG139-${_fixtureDay(-5).replaceAll('-', '')}-cd5',
          'date': _fixtureDay(-5),
          'flyers': ['Rakib Hasan'],
          'bookedKg': 26,
          'spaceKg': 44,
          'status': 'completed',
          'shipmentCount': 3,
          'revenue': 24700,
          'costs': 2950,
          'profit': 15750,
          'missingCostCount': 1,
        },
      ],
      'collect': {
        'afterDeliveryDue': 17550,
        'afterDeliveryCount': 2,
        'overdueCount': 1,
        'monthlyDue': 19600,
        'monthlyCustomers': 2,
        'month': _fixtureDay(0).substring(0, 7),
        'monthLabel': 'October 2026',
      },
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
          'costTotal': 670,
          'usualCosts': _usual(150, 0, 400, 120),
          'profitBeforeTicket': 4130,
        },
      ],
    };

/// The four usual costs; 0 means not added yet.
List<Map<String, Object?>> _usual(
        double packaging, double courier, double customs, double transport) =>
    [
      {'category': 'packaging', 'amount': packaging},
      {'category': 'courier', 'amount': courier},
      {'category': 'customs', 'amount': customs},
      {'category': 'transport', 'amount': transport},
    ];

String _fixtureDay(int offset) => DateTime.now()
    .add(Duration(days: offset))
    .toIso8601String()
    .substring(0, 10);

Map<String, Object?> _leg(String from, String fromCity, String to,
        String toCity, String dep, String arr) =>
    {
      'source': 'manual',
      'code': 'BG',
      'date': null,
      'fromIata': from,
      'fromCity': fromCity,
      'toIata': to,
      'toCity': toCity,
      'depTime': dep,
      'arrTime': arr,
    };

/// Admin flight row; money and capacity default to an unpaid ticket.
Map<String, Object?> _adminFlight(String number, int offset,
        {required double booked,
        required int space,
        required int shipments,
        List<String> flyers = const [],
        String status = 'upcoming',
        int mobiles = 2,
        int laptops = 1}) =>
    {
      'code':
          '$number-${_fixtureDay(offset).replaceAll('-', '')}-cd${offset.abs()}',
      'date': _fixtureDay(offset),
      'depTime': '10:40',
      'arrTime': '15:25',
      'via': 'Via KMG Kunming',
      'legs': [
        _leg('TFU', 'Chengdu', 'KMG', 'Kunming', '10:40', '12:10'),
        _leg('KMG', 'Kunming', 'DAC', 'Dhaka', '13:30', '15:25'),
      ],
      'fare': 0,
      'actualCost': 30000,
      'agencyShare': 6000,
      'flyerDue': 24000,
      'ticketPaid': 0,
      'ticketDue': 30000,
      'spaceKg': space,
      'mobiles': mobiles,
      'laptops': laptops,
      'bookedKg': booked,
      'leftKg': space - booked,
      'status': status,
      'statusLabel': status == 'completed' ? 'Completed' : 'Upcoming',
      'flyers': flyers,
      'shipmentCount': shipments,
      'revenue': 0,
      'scheduleNeedsConfirmation': false,
      'settlements': [],
    };

Map<String, Object?> _flightsBody() => {
      'flights': [
        {
          'code': 'BG305-20261021-ab12cd',
          'date': _fixtureDay(3),
          'depTime': '09:40',
          'arrTime': '12:10',
          'via': 'Direct',
          'legs': [_leg('TFU', 'Chengdu', 'DAC', 'Dhaka', '09:40', '12:10')],
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
        _adminFlight('BG147', 9,
            booked: 18.4, space: 40, shipments: 2, flyers: ['Sumi Akter']),
        _adminFlight('BG152', 12,
            booked: 5.5, space: 30, shipments: 1, mobiles: 2),
        _adminFlight('BG139', -5,
            booked: 26,
            space: 44,
            shipments: 3,
            flyers: ['Rakib Hasan'],
            status: 'completed'),
      ],
    };

Map<String, Object?> _adminBooking(String code,
        {required String supplier,
        required String status,
        required int statusIndex,
        required double kg,
        required double bill,
        required double paid,
        List<double> costs = const [0, 0, 0, 0],
        String terms = 'invoice'}) =>
    {
      ..._shipment(code: code, status: status, statusIndex: statusIndex),
      'bookedKg': kg,
      'effectiveKg': kg,
      'supplierName': supplier,
      'charge': bill,
      'billAmount': bill,
      'discountAmount': 0,
      'paidAmount': paid,
      'dueAmount': bill - paid,
      'payStatus': paid >= bill
          ? 'paid'
          : paid > 0
              ? 'partial'
              : 'unpaid',
      'payMethod': null,
      'paymentTerms': terms,
      'freeOfCharge': false,
      'receiptStatus': null,
      'costTotal': costs.fold<double>(0, (sum, cost) => sum + cost),
      'usualCosts': _usual(costs[0], costs[1], costs[2], costs[3]),
      'profitBeforeTicket':
          bill - costs.fold<double>(0, (sum, cost) => sum + cost),
    };

/// BG305 with two flyers part-paid, an unassigned early payment and four
/// bookings, for the flight and ticket money screenshots.
Map<String, Object?> _flightDetailFull() {
  final flight = Map<String, Object?>.from(
      (_flightsBody()['flights'] as List).first as Map);
  flight.addAll({
    'flyers': ['Arif Rahman', 'Rakib Hasan'],
    'actualCost': 42000,
    'agencyShare': 12000,
    'ticketPaid': 28000,
    'ticketDue': 14000,
    'ticketRefundDue': 0,
    'flyerDue': 7000,
    'unallocatedFlyerPaid': 2000,
    'mobiles': 4,
    'laptops': 2,
    'shipmentCount': 4,
    'revenue': 32725,
    'totalShipmentCosts': 3620,
    'margin': 17105,
    'settlements': [
      {'name': 'Arif Rahman', 'contribution': 15000, 'paidAmount': 15000},
      {'name': 'Rakib Hasan', 'contribution': 15000, 'paidAmount': 6000},
    ],
    'flyerDetails': [
      {'name': 'Arif Rahman', 'bdPhone': '01800000000', 'initial': 'A'},
      {'name': 'Rakib Hasan', 'bdPhone': '01900000000', 'initial': 'R'},
    ],
    'bookings': [
      _adminBooking('SH-18',
          supplier: 'Nila Store',
          status: 'ready_for_shipment',
          statusIndex: 2,
          kg: 4,
          bill: 4600,
          paid: 1000,
          costs: [150, 0, 400, 120]),
      _adminBooking('SH-21',
          supplier: 'Rahman Traders',
          status: 'ready_for_shipment',
          statusIndex: 2,
          kg: 12.5,
          bill: 11875,
          paid: 11875,
          costs: [250, 350, 900, 200]),
      _adminBooking('SH-51',
          supplier: 'Sky Mobile',
          status: 'received_cn_hub',
          statusIndex: 1,
          kg: 9,
          bill: 10550,
          paid: 0,
          costs: [200, 300, 750, 0]),
      _adminBooking('SH-53',
          supplier: 'Nila Store',
          status: 'pending',
          statusIndex: 0,
          kg: 6,
          bill: 5700,
          paid: 0),
    ],
  });
  return {'flight': flight};
}

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

/// One page of `GET /api/finance/ledger`: a payment, an expense, both sides
/// of a CNY transfer and a reversal.
Map<String, Object?> ledgerBody() {
  Map<String, Object?> line(
          String id,
          String kind,
          String key,
          String at,
          String type,
          String description,
          String? account,
          String currency,
          double amount,
          {String reference = '',
          bool canReverse = true,
          String? reversalOfId,
          String? shipmentCode}) =>
      {
        'recordId': id,
        'reversalKind': kind,
        'canReverse': canReverse,
        'reversedAt': null,
        'reversalOfId': reversalOfId,
        'key': key,
        'at': at,
        'type': type,
        'description': description,
        'reference': reference,
        'account': account,
        'currency': currency,
        'amount': amount,
        'shipmentCode': shipmentCode,
      };
  return {
    'entries': [
      line('p1', 'payment', 'k1', '2026-10-24T08:05:00.000Z', 'customer',
          'Nila Store / 8N4K2LQ7', 'bKash Business', 'BDT', 3200,
          reference: 'Nila Store / 8N4K2LQ7', shipmentCode: 'SH-18'),
      line(
          'e1',
          'expense',
          'k2',
          '2026-10-24T06:00:00.000Z',
          'expense',
          'Van hire, office to Shahjalal cargo terminal',
          'Dhaka cash',
          'BDT',
          -1850,
          reference: 'transport'),
      line('t1', 'transfer', 'k3', '2026-10-23T05:00:00.000Z', 'transfer',
          'To Chengdu cash · Weekly hub float', 'Dhaka cash', 'BDT', -17500),
      line('t1', 'transfer', 'k4', '2026-10-23T05:00:00.000Z', 'transfer',
          'From Dhaka cash · Weekly hub float', 'Chengdu cash', 'CNY', 1000),
      line('e2', 'expense', 'k5', '2026-10-20T04:00:00.000Z', 'expense',
          'Courier to Uttara', 'Dhaka cash', 'BDT', 600,
          reference: 'courier', canReverse: false, reversalOfId: 'e0'),
    ],
    'total': 64,
    'page': 1,
    'limit': 25,
    'totals': [
      {'currency': 'BDT', 'moneyIn': 64200, 'moneyOut': 31850},
      {'currency': 'CNY', 'moneyIn': 1400, 'moneyOut': 400},
    ],
  };
}

/// BG305 as drawn in the flow designs: two flyers paying part, four
/// shipments with their usual costs.
const flowFlightCode = 'BG305-20261021-ef56gh';

Map<String, Object?> flowFlightDetailBody() {
  final flight = Map<String, Object?>.from(
      (_flightsBody()['flights'] as List).first as Map);
  flight.addAll({
    'code': flowFlightCode,
    'legs': [
      {
        ..._leg('TFU', 'Chengdu', 'DAC', 'Dhaka', '09:40', '12:10'),
        'source': 'ticket',
      }
    ],
    'flyers': ['Arif Rahman', 'Rakib Hasan'],
    'fare': 30000,
    'actualCost': 42000,
    'agencyShare': 12000,
    'flyerPaidAmount': 21000,
    'ticketPaid': 28000,
    'ticketDue': 14000,
    'ticketRefundDue': 0,
    'flyerDue': 9000,
    'unallocatedFlyerPaid': 0,
    'mobiles': 4,
    'laptops': 2,
    'shipmentCount': 4,
    'revenue': 31800,
    'totalShipmentCosts': 3620,
    'margin': 16180,
    'settlements': [
      {'name': 'Arif Rahman', 'contribution': 15000, 'paidAmount': 15000},
      {'name': 'Rakib Hasan', 'contribution': 15000, 'paidAmount': 6000},
    ],
    'flyerDetails': [
      {'name': 'Arif Rahman', 'bdPhone': '01800000000', 'initial': 'A'},
      {'name': 'Rakib Hasan', 'bdPhone': '01811000000', 'initial': 'R'},
    ],
    'bookings': [
      _adminBooking('SH-18',
          supplier: 'Nila Store',
          status: 'received_bd_hub',
          statusIndex: 5,
          kg: 4,
          bill: 4800,
          paid: 1000,
          costs: [150, 0, 400, 120],
          terms: 'monthly'),
      _adminBooking('SH-21',
          supplier: 'Rahman Traders',
          status: 'delivered',
          statusIndex: 8,
          kg: 12.5,
          bill: 11250,
          paid: 0,
          costs: [250, 350, 900, 200]),
      _adminBooking('SH-51',
          supplier: 'Sky Mobile',
          status: 'out_for_delivery',
          statusIndex: 7,
          kg: 9,
          bill: 10050,
          paid: 0,
          costs: [200, 300, 750, 0]),
      _adminBooking('SH-53',
          supplier: 'Nila Store',
          status: 'ready_for_shipment',
          statusIndex: 2,
          kg: 6,
          bill: 5700,
          paid: 0,
          terms: 'monthly'),
    ],
  });
  return {'flight': flight};
}

/// `GET /api/dashboard/collect` with the numbers of the Get paid design.
Map<String, Object?> collectBody() {
  final month = _fixtureDay(0).substring(0, 7);
  return {
    'today': _fixtureDay(0),
    'afterDelivery': {
      'handedOver': [
        {
          'code': 'SH-14',
          'supplierCode': 'C-22',
          'supplierName': 'Bismillah Telecom',
          'supplierPhone': '01712000000',
          'amount': 6300,
          'deliveredOn': _fixtureDay(-9),
          'days': 9,
          'overdue': true,
        },
        {
          'code': 'SH-21',
          'supplierCode': 'C-15',
          'supplierName': 'Rahman Traders',
          'supplierPhone': '01713000000',
          'amount': 11250,
          'deliveredOn': _fixtureDay(-1),
          'days': 1,
          'overdue': false,
        },
      ],
      'comingSoon': [
        {
          'code': 'SH-51',
          'supplierCode': 'C-31',
          'supplierName': 'Sky Mobile',
          'amount': 10050,
          'status': 'out_for_delivery',
          'statusLabel': 'Out for Delivery',
        },
      ],
      'due': 17550,
      'overdueCount': 1,
    },
    'monthly': {
      'month': month,
      'monthLabel': 'October 2026',
      'customers': [
        {
          'code': 'C-14',
          'name': 'Nila Store',
          'phone': '01700000000',
          'billed': 18600,
          'paid': 3200,
          'due': 15400,
          'shipments': 4,
          'linkSentOn': _fixtureDay(-3),
          'linkActive': true,
        },
        {
          'code': 'C-27',
          'name': 'Mou Cosmetics',
          'phone': '01714000000',
          'billed': 4200,
          'paid': 0,
          'due': 4200,
          'shipments': 1,
          'linkSentOn': null,
          'linkActive': false,
        },
      ],
      'due': 19600,
    },
  };
}

/// `GET /api/dashboard/overview` as the fixture server sends it.
Map<String, Object?> overviewBody() => _overviewBody();
