import 'dart:convert';

import 'package:http/http.dart' as http;

/// Sample data for the flyer, task, staff, settings and invoice screens.
/// Pass [teamFixtures] as the `intercept` of `screenFixtureApi`; anything it
/// does not answer falls through to the shared fixtures. Names and numbers
/// are made up.
Future<http.Response?> teamFixtures(http.Request request,
    {String invoiceState = 'draft',
    bool needsReview = false,
    bool cleanupEnabled = false}) async {
  final path = request.url.path;
  if (request.method != 'GET') return null;
  Object? body;
  if (path == '/api/flyers') {
    body = {'flyers': teamFlyers()};
  } else if (path.startsWith('/api/flyers/') && path.endsWith('/documents')) {
    body = {'configured': true, 'documents': teamFlyerDocuments()};
  } else if (path.startsWith('/api/flyers/')) {
    body = {'flyer': teamFlyerDetail()};
  } else if (path == '/api/settings/users') {
    body = {'users': teamStaff()};
  } else if (path == '/api/settings/setup-status') {
    body = {
      'rateConfirmed': true,
      'accounts': 5,
      'paymentMethods': 3,
      'users': 2,
      'storageConfigured': true,
      'cleanupEnabled': cleanupEnabled,
      'lastCleanupAt': null
    };
  } else if (path == '/api/settings/pay-methods') {
    body = {'methods': teamPayMethods()};
  } else if (path == '/api/todos') {
    body = {'todos': teamTasks()};
  } else if (path.endsWith('/invoice')) {
    body = teamInvoice(state: invoiceState, needsReview: needsReview);
  }
  if (body == null) return null;
  return http.Response.bytes(utf8.encode(jsonEncode(body)), 200,
      headers: {'content-type': 'application/json; charset=utf-8'});
}

Map<String, Object?> _flyer(String first, String last,
        {required String phone,
        required String university,
        bool id = false,
        bool visa = false,
        bool admission = false,
        int documents = 0,
        int verified = 0}) =>
    {
      'name': '$first $last',
      'firstName': first,
      'lastName': last,
      'cnPhone': '+86 13800000000',
      'bdPhone': phone,
      'university': university,
      'batch': '2023',
      'program': 'MBBS',
      'wechat': '${first.toLowerCase()}_scu23',
      'docStudentId': id,
      'docVisa': visa,
      'docAdmission': admission,
      'documentCount': documents,
      'verifiedDocumentCount': verified,
      'archivedAt': null,
    };

List<Map<String, Object?>> teamFlyers() => [
      _flyer('Arif', 'Rahman',
          phone: '01800000000',
          university: 'Sichuan University',
          id: true,
          visa: true,
          documents: 3,
          verified: 2),
      _flyer('Rakib', 'Hasan',
          phone: '01811000000',
          university: 'Southwest Jiaotong University',
          id: true,
          documents: 2,
          verified: 1),
      _flyer('Sumi', 'Akter',
          phone: '01822000000',
          university: 'Chengdu Medical College',
          id: true,
          visa: true,
          admission: true,
          documents: 3,
          verified: 3),
      _flyer('Tanvir', 'Ahmed',
          phone: '01833000000', university: 'Sichuan University'),
    ];

Map<String, Object?> teamFlyerDetail() {
  String day(int offset) => DateTime.now()
      .add(Duration(days: offset))
      .toIso8601String()
      .substring(0, 10);
  return {
    ...teamFlyers().first,
    'cnAddress': 'Wangjiang Campus, Chengdu',
    'homeAddress': 'Mirpur, Dhaka',
    'emergencyContact': 'Father · 01711000000',
    'totalKg': 78,
    'nextFlight': null,
    'flights': [
      {
        'code': 'BG147-${day(2).replaceAll('-', '')}-ab12cd',
        'date': day(2),
        'depTime': '10:40',
        'arrTime': '15:25',
        'spaceKg': 44,
        'bookedKg': 36,
        'status': 'upcoming',
        'statusLabel': 'Upcoming',
      },
      {
        'code': 'BG305-${day(-35).replaceAll('-', '')}-ab12cd',
        'date': day(-35),
        'depTime': '09:40',
        'arrTime': '12:10',
        'spaceKg': 44,
        'bookedKg': 42,
        'status': 'completed',
        'statusLabel': 'Completed',
      },
    ],
  };
}

List<Map<String, Object?>> teamFlyerDocuments() => [
      {
        'reference': 'doc-1',
        'kind': 'student_id',
        'name': 'student-id.jpg',
        'contentType': 'image/jpeg',
        'size': 120000,
        'createdAt': '2026-10-20T09:00:00.000Z',
        'uploadedByName': 'Rafiq',
        'verifiedAt': '2026-10-20T10:00:00.000Z',
        'verifiedByName': 'Rafiq',
      },
      {
        'reference': 'doc-2',
        'kind': 'visa',
        'name': 'visa-2026.pdf',
        'contentType': 'application/pdf',
        'size': 340000,
        'createdAt': '2026-10-20T09:05:00.000Z',
        'uploadedByName': 'Rafiq',
        'verifiedAt': '2026-10-20T10:05:00.000Z',
        'verifiedByName': 'Rafiq',
      },
      {
        'reference': 'doc-3',
        'kind': 'admission',
        'name': 'admission-letter.pdf',
        'contentType': 'application/pdf',
        'size': 280000,
        'createdAt': '2026-10-21T09:00:00.000Z',
        'uploadedByName': 'Rafiq',
        'verifiedAt': null,
        'verifiedByName': null,
      },
    ];

List<Map<String, Object?>> teamStaff() => [
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
      {
        'id': 'u3',
        'name': 'Jamal Hossain',
        'email': 'jamal@sbx.test',
        'role': 'hub',
        'active': false
      },
    ];

List<Map<String, Object?>> teamPayMethods() => [
      {
        'id': 'm1',
        'kind': 'mobile_banking',
        'provider': 'bKash',
        'label': 'Business',
        'number': '01900000000',
        'bankName': '',
        'accountName': '',
        'enabled': true,
        'currency': 'BDT'
      },
      {
        'id': 'm2',
        'kind': 'mobile_banking',
        'provider': 'Nagad',
        'label': '',
        'number': '01600000000',
        'bankName': '',
        'accountName': '',
        'enabled': false,
        'currency': 'BDT'
      },
      {
        'id': 'm3',
        'kind': 'bank_account',
        'provider': 'bank',
        'label': '',
        'number': '',
        'bankName': 'City Bank',
        'accountName': 'SB Express',
        'enabled': true,
        'currency': 'BDT'
      },
    ];

List<Map<String, Object?>> teamTasks() => [
      {
        'id': 't1',
        'text': 'Review bKash receipt — SH-18',
        'auto': true,
        'done': false,
        'href': '/review'
      },
      {
        'id': 't2',
        'text': 'Weigh SH-19 at the hub',
        'auto': true,
        'done': false,
        'href': '/shipments/SH-19'
      },
      {
        'id': 't3',
        'text': 'Call Sky Mobile about the SH-53 balance',
        'auto': false,
        'done': false
      },
      {
        'id': 't4',
        'text': 'Review Nagad receipt — SH-21',
        'auto': true,
        'done': true,
        'href': '/review'
      },
    ];

Map<String, Object?> teamInvoice(
        {String state = 'draft', bool needsReview = false}) =>
    {
      'saved': state == 'issued',
      'invoice': {
        'state': state,
        'needsReview': needsReview,
        'pricingMode': 'automatic',
        'number': 'INV-2610-SH-18',
        'lines': [
          {'label': 'Shipping 4 kg × ৳950', 'amount': 3800},
          {'label': 'Customs tax', 'amount': 400},
          {'label': 'Packing', 'amount': 50},
        ],
        'discount': 250,
        'note': 'Pay by bKash and write SH-18 as the reference.',
        'total': 4000,
        'paidAmount': state == 'issued' ? 1000 : 0,
        'dueAmount': state == 'issued' ? 3000 : 4000,
      },
    };
