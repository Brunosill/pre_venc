import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../../../core/utils/hive_boxes.dart';
import '../../../product/domain/entities/product.dart';
import '../../../product/presentation/providers/product_providers.dart';
import '../../data/models/alert_settings_model.dart';
import '../../data/services/alert_scheduler.dart';
import '../../domain/entities/alert_settings.dart';

// Box
final alertSettingsBoxProvider =
    Provider<Box<AlertSettingsModel>>((ref) => HiveBoxes.alertSettingsBox);

// Scheduler
final alertSchedulerProvider = Provider<AlertScheduler>((ref) {
  return AlertScheduler(notifications: FlutterNotificationScheduler());
});

// Configurações atuais (reativo)
final alertSettingsProvider = StreamProvider<AlertSettings>((ref) async* {
  final box = ref.watch(alertSettingsBoxProvider);

  AlertSettings readSettings() {
    final model = box.get('settings');
    if (model == null) return const AlertSettings();
    return AlertSettings(
      daysBefore: model.daysBefore,
      enabled: model.enabled,
    );
  }

  yield readSettings();
  await for (final _ in box.watch()) {
    yield readSettings();
  }
});

// Salvar configurações (com reagendamento)
final saveAlertSettingsProvider =
    Provider<Future<void> Function(AlertSettings)>((ref) {
  final box = ref.watch(alertSettingsBoxProvider);
  final scheduler = ref.watch(alertSchedulerProvider);

  return (settings) async {
    await box.put(
      'settings',
      AlertSettingsModel(
        daysBefore: settings.daysBefore,
        enabled: settings.enabled,
      ),
    );

    // Reagenda com a nova configuração
    final products = ref.read(productsStreamProvider).asData?.value ?? const <Product>[];
    final model = box.get('settings');
    if (model != null) {
      await scheduler.rescheduleAll(products, model);
    }
  };
});

// Reagendamento sob demanda (usado ao salvar/deletar produto)
final rescheduleAlertsProvider = Provider<Future<void> Function()>((ref) {
  final scheduler = ref.watch(alertSchedulerProvider);
  final box = ref.watch(alertSettingsBoxProvider);

  return () async {
    final products =
        ref.read(productsStreamProvider).asData?.value ?? const <Product>[];
    final model = box.get('settings') ??
        AlertSettingsModel(daysBefore: const [30, 1], enabled: true);
    await scheduler.rescheduleAll(products, model);
  };
});

// Lista de produtos que vencem em até 7 dias (para o banner)
final expiringThisWeekProvider = Provider<List<Product>>((ref) {
  final products =
      ref.watch(productsStreamProvider).asData?.value ?? const <Product>[];
  return products
      .where((p) =>
          p.daysToExpire != null &&
          p.daysToExpire! >= 0 &&
          p.daysToExpire! <= 7)
      .toList();
});
