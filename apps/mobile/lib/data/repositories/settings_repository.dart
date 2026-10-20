import '../api/api_client.dart';
import '../json_read.dart';
import '../models/workspace.dart';

class SettingsRepository {
  SettingsRepository(this.api);

  final ApiClient api;

  Future<SetupStatus> setup() async {
    final json = await api.getJson('/api/settings/setup-status');
    return SetupStatus.fromJson(json);
  }

  Future<SettingsSnapshot> current() async {
    final json = await api.getJson('/api/settings');
    return SettingsSnapshot.fromJson(asJsonMap(json['settings'], 'settings'));
  }

  Future<SettingsSnapshot> saveRate(double rate) async {
    final json = await api.patchJson('/api/settings', body: {'rate': rate});
    return SettingsSnapshot.fromJson(asJsonMap(json['settings'], 'settings'));
  }

  Future<List<String>> categories() async {
    final json = await api.getJson('/api/categories');
    return requiredStringList(json, 'categories');
  }

  Future<void> addCategory(String name) async {
    await api.postJson('/api/categories', body: {'name': name});
  }

  Future<List<PayMethodInfo>> payMethods() async {
    final json = await api.getJson('/api/settings/pay-methods');
    return [for (final row in requiredMapList(json, 'methods')) PayMethodInfo.fromJson(row)];
  }

  Future<List<StaffAccount>> staff() async {
    final json = await api.getJson('/api/settings/users');
    return [for (final row in requiredMapList(json, 'users')) StaffAccount.fromJson(row)];
  }
}
