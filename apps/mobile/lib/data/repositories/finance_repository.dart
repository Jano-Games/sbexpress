import '../api/api_client.dart';
import '../models/finance_snapshot.dart';

class FinanceRepository {
  FinanceRepository(this.api);

  final ApiClient api;

  Future<FinanceSnapshot> snapshot({String period = 'week'}) async {
    final json = await api.getJson('/api/finance?period=${Uri.encodeQueryComponent(period)}');
    return FinanceSnapshot.fromJson(json);
  }
}
