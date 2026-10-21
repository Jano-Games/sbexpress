import '../api/api_client.dart';
import '../models/dashboard.dart';
import '../models/workspace.dart';

class DashboardRepository {
  DashboardRepository(this.api);

  final ApiClient api;

  Future<HubDashboard> hub() async {
    final json = await api.getJson('/api/dashboard/hub');
    return HubDashboard.fromJson(json);
  }

  Future<DashboardCounts> counts() async {
    final json = await api.getJson('/api/dashboard/counts');
    return DashboardCounts.fromJson(json);
  }

  Future<AdminOverview> overview() async {
    final json = await api.getJson('/api/dashboard/overview');
    return AdminOverview.fromJson(json);
  }
}
