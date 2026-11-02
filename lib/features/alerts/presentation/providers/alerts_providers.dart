import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../../../core/utils/hive_boxes.dart';
import '../../../product/data/models/inventory_item.dart';
import '../../../product/presentation/providers/inventory_providers.dart';
import '../../data/models/alert_settings_model.dart';
import '../../data/services/alert_scheduler.dart';
import '../../data/services/flutter_notification_scheduler.dart';
import '../../domain/entities/alert_settings.dart';

// Box
final alertSettingsBoxProvider =
    Provider<Box<AlertSettingsModel>>((ref) => HiveBoxes.alertSettingsBox);

// Scheduler (injeção direta)
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

    final items =
        ref.read(inventoryItemsStreamProvider).asData?.value ?? const <InventoryItem>[];
    final model = box.get('settings');
    if (model != null) {
      await scheduler.rescheduleAll(items, model);
    }
  };
});

// Reagendamento sob demanda
final rescheduleAlertsProvider = Provider<Future<void> Function()>((ref) {
  final scheduler = ref.watch(alertSchedulerProvider);
  final box = ref.watch(alertSettingsBoxProvider);

  return () async {
    final items =
        ref.read(inventoryItemsStreamProvider).asData?.value ?? const <InventoryItem>[];
    final model = box.get('settings') ??
        AlertSettingsModel(daysBefore: const [30, 1], enabled: true);
    await scheduler.rescheduleAll(items, model);
  };
});

// Produtos que vencem em até 7 dias
final expiringThisWeekProvider = Provider<List<InventoryItem>>((ref) {
  final items =
      ref.watch(inventoryItemsStreamProvider).asData?.value ?? const <InventoryItem>[];
  
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  return items.where((item) {
    if (item.expirationDate == null) return false;
    final exp = item.expirationDate!;
    final days = DateTime(exp.year, exp.month, exp.day).difference(today).inDays;
    return days >= 0 && days <= 7;
  }).toList();
});
