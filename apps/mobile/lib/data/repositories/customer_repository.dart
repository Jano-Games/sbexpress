import '../api/api_client.dart';
import '../json_read.dart';
import '../models/customer.dart';

class CustomerRepository {
  CustomerRepository(this.api);

  final ApiClient api;

  Future<List<CustomerSummary>> list() async {
    final json = await api.getJson('/api/suppliers');
    return [for (final row in requiredMapList(json, 'suppliers')) CustomerSummary.fromJson(row)];
  }

  Future<CustomerDetail> detail(String code) async {
    final json = await api.getJson(_path(code));
    return CustomerDetail.fromJson(asJsonMap(json['supplier'], 'supplier'));
  }

  Future<String> create(CustomerDraft draft) async {
    final json = await api.postJson('/api/suppliers', body: draft.toJson());
    return requiredString(json, 'code');
  }

  String _path(String code) => '/api/suppliers/${Uri.encodeComponent(code)}';
}
