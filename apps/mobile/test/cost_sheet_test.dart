import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sbexpress/data/api/api_client.dart';
import 'package:sbexpress/data/repositories/shipment_repository.dart';
import 'package:sbexpress/data/session/session_store.dart';

void main() {
  test('the cost sheet is read from inside the shipment detail', () async {
    final api = ApiClient(
      baseUrl: 'http://localhost:3002',
      session: MemorySessionStore()..token = 'tok',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/api/shipments/SH-101');
        return http.Response(
            jsonEncode({
              'shipment': {
                'code': 'SH-101',
                'costs': {
                  'items': [
                    {
                      'id': 'cost-1',
                      'name': 'Courier to customer',
                      'category': 'courier',
                      'amount': 300,
                      'paidAmount': 300,
                      'dueAmount': 0,
                      'costField': null,
                      'voidedAt': null,
                    },
                  ],
                  'total': 300,
                  'unpaidCosts': {'cnFare': 0, 'bdFare': 0, 'customsTax': 0},
                },
              },
            }),
            200,
            headers: {'content-type': 'application/json'});
      }),
    );

    final sheet = await ShipmentRepository(api).costSheet('SH-101');

    expect(sheet.total, 300);
    expect(sheet.items.single.name, 'Courier to customer');
  });
}
