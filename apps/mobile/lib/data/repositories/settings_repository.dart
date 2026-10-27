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

  /// The weight alert: booked and weighed kg this far apart get flagged.
  Future<SettingsSnapshot> saveThreshold(double kg) async {
    final json = await api.patchJson('/api/settings', body: {'threshold': kg});
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
    return [
      for (final row in requiredMapList(json, 'methods'))
        PayMethodInfo.fromJson(row)
    ];
  }

  Future<List<StaffAccount>> staff() async {
    final json = await api.getJson('/api/settings/users');
    return [
      for (final row in requiredMapList(json, 'users'))
        StaffAccount.fromJson(row)
    ];
  }

  Future<void> createPayMethod(Map<String, Object?> body) async {
    await api.postJson('/api/settings/pay-methods', body: body);
  }

  Future<void> setPayMethodEnabled(String id, {required bool enabled}) async {
    await api.patchJson('/api/settings/pay-methods/${Uri.encodeComponent(id)}',
        body: {'enabled': enabled});
  }

  Future<StaffAccount> createStaff(
      {required String name,
      required String email,
      required String role,
      required String password}) async {
    final json = await api.postJson('/api/settings/users', body: {
      'name': name,
      'email': email,
      'role': role,
      'password': password,
    });
    return StaffAccount.fromJson(asJsonMap(json['user'], 'user'));
  }

  Future<StaffAccount> updateStaff(String id, Map<String, Object?> body) async {
    final json = await api.patchJson(
        '/api/settings/users/${Uri.encodeComponent(id)}',
        body: body);
    return StaffAccount.fromJson(asJsonMap(json['user'], 'user'));
  }

  Future<void> setPassword(String id,
      {required String password, String? currentPassword}) async {
    await api.postJson(
        '/api/settings/users/${Uri.encodeComponent(id)}/password',
        body: {
          'password': password,
          if (currentPassword != null && currentPassword.isNotEmpty)
            'currentPassword': currentPassword,
        });
  }
}
