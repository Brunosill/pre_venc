import '../../../product/domain/entities/product.dart';
import '../models/alert_settings_model.dart';
import 'notification_service.dart';

class AlertScheduler {
  /// Reagenda todas as notificações a partir da lista de produtos.
  /// Cancela todas as anteriores primeiro para evitar órfãs.
  Future<void> rescheduleAll(
    List<Product> products,
    AlertSettingsModel settings,
  ) async {
    await NotificationService.cancelAll();

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
          9, // notifica às 9h da manhã
          0,
        ).subtract(Duration(days: daysBefore));

        if (scheduledDate.isBefore(now)) continue;

        // ID único: base + hash do produto + dias antes
        final id = _notificationId(product.id, daysBefore);

        final whenLabel = daysBefore == 0
            ? 'hoje'
            : daysBefore == 1
                ? 'amanhã'
                : 'em $daysBefore dias';

        await NotificationService.scheduleAt(
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

  /// Cancela as notificações de um produto específico.
  Future<void> cancelForProduct(Product product, AlertSettingsModel settings) async {
    for (final daysBefore in settings.daysBefore) {
      final id = _notificationId(product.id, daysBefore);
      await NotificationService.cancel(id);
    }
  }

  int _notificationId(String productId, int daysBefore) {
    // Garante ID positivo e estável
    final hash = productId.hashCode.abs() % 100000;
    return hash * 100 + daysBefore.clamp(0, 99);
  }
}
