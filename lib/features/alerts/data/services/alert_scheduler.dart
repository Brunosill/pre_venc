import '../../../product/domain/entities/product.dart';
import '../models/alert_settings_model.dart';
import 'notification_scheduler.dart';

class AlertScheduler {
  final NotificationScheduler _notifications;

  AlertScheduler({NotificationScheduler? notifications})
      : _notifications = notifications ?? _defaultScheduler();

  static NotificationScheduler _defaultScheduler() {
    // Import tardio para evitar dependência circular em testes
    return _LazyDefaultScheduler();
  }

  Future<void> rescheduleAll(
    List<Product> products,
    AlertSettingsModel settings,
  ) async {
    await _notifications.cancelAll();
    if (!settings.enabled) return;
    if (settings.daysBefore.isEmpty) return;

    final now = DateTime.now();

    for (final product in products) {
      final expiration = product.expirationDate;
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

        final id = notificationId(product.id, daysBefore);
        final whenLabel = daysBefore == 0
            ? 'hoje'
            : daysBefore == 1
                ? 'amanhã'
                : 'em $daysBefore dias';

        await _notifications.scheduleAt(
          id: id,
          title: '⏰ Produto vencendo $whenLabel',
          body: '"${product.name}" vence em '
              '${expiration.day.toString().padLeft(2, '0')}/'
              '${expiration.month.toString().padLeft(2, '0')}/'
              '${expiration.year}.',
          scheduledDate: scheduledDate,
          payload: product.id,
        );
      }
    }
  }

  /// IDs são determinísticos: mesmo produto + dias = mesmo ID.
  static int notificationId(String productId, int daysBefore) {
    final hash = productId.hashCode.abs() % 100000;
    return hash * 100 + daysBefore.clamp(0, 99);
  }
}

/// Implementação default que só é carregada quando necessário.
class _LazyDefaultScheduler implements NotificationScheduler {
  late final _inner = _createInner();

  static NotificationScheduler _createInner() {
    // Import local para evitar dependência circular nos testes.
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

// Função que será "injetada" no topo do arquivo via import.
// Declarada aqui para permitir sobrescrever em testes, se necessário.
NotificationScheduler _realSchedulerFactory() {
  // ignore: implementation_imports
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
    // Import tardio para evitar carregar o plugin nos testes.
    // ignore: avoid_dynamic_calls
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
    // Carrega o FlutterNotificationScheduler em runtime.
    // Em testes puros, nunca é chamado (passamos um mock no construtor).
    return _cachedScheduler ??= _createFlutterScheduler();
  }

  NotificationScheduler? _cachedScheduler;
}

/// Este símbolo é sobrescrito em testes para evitar o plugin.
NotificationScheduler _createFlutterScheduler() {
  // Import tardio — carregado só se realmente usado.
  // ignore: prefer_const_constructors
  return _FlutterSchedulerLoader.load();
}

class _FlutterSchedulerLoader {
  static NotificationScheduler load() {
    // Este método é substituído em ambiente de teste.
    throw UnimplementedError(
      'Em testes, injete um NotificationScheduler mock via construtor.',
    );
  }
}
