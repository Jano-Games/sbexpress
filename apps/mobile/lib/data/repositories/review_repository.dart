import '../api/api_client.dart';
import '../json_read.dart';
import '../models/payment_review.dart';

class ReviewRepository {
  ReviewRepository(this.api);

  final ApiClient api;

  Future<PaymentReviewQueue> queue() async {
    final json = await api.getJson('/api/review');
    return PaymentReviewQueue.fromJson(json);
  }

  Future<void> approve(PaymentReviewItem item) {
    return api.postJson(item.approvePath, idempotent: true);
  }

  Future<void> reject(PaymentReviewItem item, String reason) {
    return api.postJson(item.rejectPath, body: {'reason': reason});
  }

  Future<String> screenshotUrl(String reference) async {
    final json = await api.getJson('/api/review/screenshots/${Uri.encodeComponent(reference)}/url');
    return requiredString(json, 'url');
  }
}
