import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

// Importações necessárias para o Isolate de background
import '../../../../core/utils/hive_boxes.dart';
import '../../../product/data/models/inventory_item.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const _channelId = 'expiration_alerts_v2';
  static const _channelName = 'Alertas de vencimento';
  static const _channelDescription = 'Notificações interativas de produtos vencendo';

  // ignore: unused_field
  static const _categoryId = 'product_expiration';

  /// Inicializa o plugin e o timezone.
  static Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
    } catch (_) {}

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint('Notificação tocada: ${details.payload}');
      },
      // Handler para quando o app está fechado ou em background
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    _initialized = true;
  }

  static Future<bool> requestPermission() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final status = await Permission.notification.request();
      return status.isGranted;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(
        alert: true, badge: true, sound: true,
      );
      return granted ?? false;
    }
    return true;
  }

  static Future<bool> hasPermission() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return Permission.notification.isGranted;
    }
    return true;
  }

  static AndroidNotificationDetails _androidDetails({
    required String title,
    required String body,
  }) {
    return AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(body),
      // Definindo as ações interativas
      actions: const [
        AndroidNotificationAction(
          'consumed',
          '✅ Consumi',
          showsUserInterface: false,
        ),
        AndroidNotificationAction(
          'discarded',
          '🗑️ Descarta',
          showsUserInterface: false,
        ),
      ],
    );
  }

  static Future<bool> scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    if (!_initialized) await init();
    if (scheduledDate.isBefore(DateTime.now())) return false;

    try {
      final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);

      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzDate,
        NotificationDetails(
          android: _androidDetails(title: title, body: body),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      return true;
    } catch (e) {
      debugPrint('Erro ao agendar notificação: $e');
      return false;
    }
  }

  static Future<void> cancel(int id) async => await _plugin.cancel(id);
  static Future<void> cancelAll() async => await _plugin.cancelAll();
}

// ============================================================================
// HANDLER DE BACKGROUND (Executa mesmo com o app fechado)
// ============================================================================
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) async {
  // Inicialização do Flutter e Hive no isolate de background
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  
  // Registra o adapter necessário
  if (!Hive.isAdapterRegistered(51)) {
    Hive.registerAdapter(InventoryItemAdapter());
  }
  
  // Abre a box de inventário
  final box = await Hive.openBox<InventoryItem>(HiveBoxes.inventoryItems);
  
  final actionId = response.actionId;
  final payload = response.payload; // Aqui vamos receber o item.id

  if (payload != null && (actionId == 'consumed' || actionId == 'discarded')) {
    final item = box.get(payload);
    if (item != null) {
      item.deletedAt = DateTime.now();
      item.syncStatus = 0; // Marca como pendente para sync com Supabase
      
      // Se foi "Consumi", podemos mudar a quantidade para 0 (opcional)
      if (actionId == 'consumed') {
        item.quantity = 0;
      }
      
      await item.save();
      debugPrint('Item $payload marcado como $actionId via notificação.');
    }
  }
  
  // Fecha o Hive para liberar memória do isolate
  await Hive.close();
}
