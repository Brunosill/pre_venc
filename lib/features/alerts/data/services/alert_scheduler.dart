import '../../../product/data/models/inventory_item.dart';
import '../models/alert_settings_model.dart';
import 'notification_scheduler.dart';

class AlertScheduler {
  final NotificationScheduler _notifications;

  AlertScheduler({NotificationScheduler? notifications})
      : _notifications = notifications ?? _defaultScheduler();

  static NotificationScheduler _defaultScheduler() {
    return _LazyDefaultScheduler();
  }

  Future<void> rescheduleAll(
    List<InventoryItem> items,
    AlertSettingsModel settings,
  ) async {
    await _notifications.cancelAll();
    if (!settings.enabled) return;
    if (settings.daysBefore.isEmpty) return;

    final now = DateTime.now();

    for (final item in items) {
      // Ignora itens deletados ou sem validade
      if (item.deletedAt != null) continue;
      final expiration = item.expirationDate;
      if (expiration == null) continue;

      for (final daysBefore in settings.daysBefore) {
        final scheduledDate = DateTime(
          expiration.year,
          expiration.month,
          expiration.day,
          9,
          0,
        ).subtract(Duration(days: daysBefore));

        if (scheduledDate.isBefore(now)) continue;

        final id = notificationId(item.id, daysBefore);
        final whenLabel = daysBefore == 0
            ? 'hoje'
            : daysBefore == 1
                ? 'amanhã'
                : 'em $daysBefore dias';

        await _notifications.scheduleAt(
          id: id,
          title: '⏰ Produto vencendo $whenLabel',
          body: '"${item.name}" vence em '
              '${expiration.day.toString().padLeft(2, '0')}/'
              '${expiration.month.toString().padLeft(2, '0')}/'
              '${expiration.year}.',
          scheduledDate: scheduledDate,
          payload: item.id,
        );
      }
    }
  }

  static int notificationId(String itemId, int daysBefore) {
    final hash = itemId.hashCode.abs() % 100000;
    return hash * 100 + daysBefore.clamp(0, 99);
  }
}

class _LazyDefaultScheduler implements NotificationScheduler {
  late final _inner = _createInner();

  static NotificationScheduler _createInner() {
    return _realSchedulerFactory();
  }

  @override
  Future<bool> scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) =>
      _inner.scheduleAt(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        payload: payload,
      );

  @override
  Future<void> cancel(int id) => _inner.cancel(id);

  @override
  Future<void> cancelAll() => _inner.cancelAll();
}

NotificationScheduler _realSchedulerFactory() {
  return _LazyFlutterScheduler();
}

class _LazyFlutterScheduler implements NotificationScheduler {
  @override
  Future<bool> scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    final service = _loadFlutterScheduler();
    return service.scheduleAt(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      payload: payload,
    );
  }

  @override
  Future<void> cancel(int id) => _loadFlutterScheduler().cancel(id);

  @override
  Future<void> cancelAll() => _loadFlutterScheduler().cancelAll();

  NotificationScheduler _loadFlutterScheduler() {
    return _cachedScheduler ??= _createFlutterScheduler();
  }

  NotificationScheduler? _cachedScheduler;
}

NotificationScheduler _createFlutterScheduler() {
  return _FlutterSchedulerLoader.load();
}

class _FlutterSchedulerLoader {
  static NotificationScheduler load() {
    throw UnimplementedError(
      'Em testes, injete um NotificationScheduler mock via construtor.',
    );
  }
}
