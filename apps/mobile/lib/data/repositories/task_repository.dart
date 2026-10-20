import '../api/api_client.dart';
import '../json_read.dart';
import '../models/task_item.dart';

class TaskRepository {
  TaskRepository(this.api);

  final ApiClient api;

  Future<List<TaskItem>> list({String? scope}) async {
    final path = scope == null ? '/api/todos' : '/api/todos?scope=${Uri.encodeQueryComponent(scope)}';
    final json = await api.getJson(path);
    return [for (final row in requiredMapList(json, 'todos')) TaskItem.fromJson(row)];
  }

  Future<void> addNote(String text, {String? assignTo}) async {
    await api.postJson('/api/todos', body: {
      'text': text,
      if (assignTo != null) 'assignTo': assignTo,
    });
  }

  Future<bool> toggle(String id) async {
    final json = await api.postJson('/api/todos/${Uri.encodeComponent(id)}/toggle');
    return requiredBool(json, 'done');
  }
}
