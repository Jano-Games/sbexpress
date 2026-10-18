import '../api/api_client.dart';
import '../json_read.dart';
import '../models/task_item.dart';

class TaskRepository {
  TaskRepository(this.api);

  final ApiClient api;

  Future<List<TaskItem>> list() async {
    final json = await api.getJson('/api/todos');
    return [for (final row in requiredMapList(json, 'todos')) TaskItem.fromJson(row)];
  }

  Future<void> addNote(String text) async {
    await api.postJson('/api/todos', body: {'text': text});
  }

  Future<bool> toggle(String id) async {
    final json = await api.postJson('/api/todos/${Uri.encodeComponent(id)}/toggle');
    return requiredBool(json, 'done');
  }
}
