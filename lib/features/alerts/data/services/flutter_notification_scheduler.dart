import 'notification_scheduler.dart';
import 'notification_service.dart';

class FlutterNotificationScheduler implements NotificationScheduler {
  @override
  Future<bool> scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) {
    return NotificationService.scheduleAt(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      payload: payload,
    );
  }

  @override
  Future<void> cancel(int id) => NotificationService.cancel(id);

  @override
  Future<void> cancelAll() => NotificationService.cancelAll();
}