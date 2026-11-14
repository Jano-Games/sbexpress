import '../api/api_client.dart';
import '../json_read.dart';
import '../models/sorting.dart';

/// The hub sorts a flight's orders per customer; the admin approves them.
class SortingRepository {
  SortingRepository(this.api);

  final ApiClient api;

  String _flight(String code) =>
      '/api/sorting/flights/${Uri.encodeComponent(code)}';

  String _customer(String code, String customer) =>
      '${_flight(code)}/customers/${Uri.encodeComponent(customer)}';

  Future<SortBoard> board(String flightCode) async =>
      SortBoard.fromJson(await api.getJson(_flight(flightCode)));

  /// Sends one customer's sorted orders to the admin.
  Future<void> sort(
    String flightCode,
    String customer, {
    required List<SortLine> orders,
    required int packages,
    required String partner,
    String? courierRef,
    String? note,
  }) async {
    await api.postJson('${_customer(flightCode, customer)}/sort', body: {
      'orders': [for (final o in orders) o.toJson()],
      'packages': packages,
      'partner': partner,
      if (courierRef != null && courierRef.trim().isNotEmpty)
        'courierRef': courierRef.trim(),
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
  }

  Future<void> approve(String flightCode, String customer) async {
    await api
        .postJson('${_customer(flightCode, customer)}/approve', body: const {});
  }

  /// Approves every customer that needs no look. Returns the approved order
  /// codes and the customers left for a person to check.
  Future<({List<String> orders, List<String> skipped})> approveAll(
      String flightCode) async {
    final json = await api
        .postJson('${_flight(flightCode)}/approve-all', body: const {});
    List<String> list(String key) =>
        json[key] is List ? asStringList(json[key], key) : const [];
    return (orders: list('approved'), skipped: list('skipped'));
  }

  Future<void> sendBack(String flightCode, String customer, String note) async {
    await api.postJson('${_customer(flightCode, customer)}/send-back',
        body: {'note': note.trim()});
  }

  Future<void> courierRef(
      String flightCode, String customer, String ref) async {
    await api.postJson('${_customer(flightCode, customer)}/courier-ref',
        body: {'ref': ref.trim()});
  }

  Future<void> delivered(
      String flightCode, String customer, String confirmation) async {
    await api.postJson('${_customer(flightCode, customer)}/delivered',
        body: {'confirmation': confirmation.trim()});
  }

  Future<Approvals> approvals() async =>
      Approvals.fromJson(await api.getJson('/api/sorting/approvals'));

  Future<HubSortSummary> hubSummary() async =>
      HubSortSummary.fromJson(await api.getJson('/api/sorting/hub-summary'));
}
