import '../api/api_client.dart';
import '../json_read.dart';
import '../models/app_notification.dart';

class NotificationRepository {
  NotificationRepository(this.api);

  final ApiClient api;

  /// The newest 100 for the signed-in role, with the unread count.
  Future<NotificationList> list() async =>
      NotificationList.fromJson(await api.getJson('/api/notifications'));

  Future<int> unread() async {
    final json = await api.getJson('/api/notifications/unread');
    return optionalInt(json, 'unread') ?? 0;
  }

  Future<void> read(String id) async {
    await api.postJson('/api/notifications/${Uri.encodeComponent(id)}/read',
        body: const {});
  }

  Future<void> readAll() async {
    await api.postJson('/api/notifications/read-all', body: const {});
  }
}
