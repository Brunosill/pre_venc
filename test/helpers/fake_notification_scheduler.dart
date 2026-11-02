import 'package:pre_venc/features/alerts/data/services/notification_scheduler.dart';

class FakeNotificationScheduler implements NotificationScheduler {
  final List<Map<String, dynamic>> scheduled = [];
  final List<int> cancelled = [];
  bool cancelAllCalled = false;

  @override
  Future<bool> scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    scheduled.add({
      'id': id,
      'title': title,
      'body': body,
      'scheduledDate': scheduledDate,
      'payload': payload,
    });
    return true;
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCalled = true;
    cancelled.clear();
  }
}
