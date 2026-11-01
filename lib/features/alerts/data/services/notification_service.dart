import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const _channelId = 'expiration_alerts';
  static const _channelName = 'Alertas de vencimento';
  static const _channelDescription =
      'Notificações de produtos próximos do vencimento';

  /// Inicializa o plugin e o timezone. Deve ser chamado no `main()`.
  static Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    // Ajusta para o fuso horário do Brasil
    try {
      tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
    } catch (_) {
      // Se o fuso não existir, usa UTC
    }

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
    );

    _initialized = true;
  }

  /// Pede permissão de notificações (Android 13+).
  static Future<bool> requestPermission() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final status = await Permission.notification.request();
      return status.isGranted;
    }
    // iOS: usar API do plugin
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    return true;
  }

  /// Verifica se já tem permissão (sem solicitar).
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
    );
  }

  /// Agenda uma notificação para o `scheduledDate`.
  /// Retorna `true` se agendou com sucesso.
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

  /// Cancela uma notificação pelo ID.
  static Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }

  /// Cancela todas as notificações agendadas.
  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// Lista IDs pendentes (debug).
  static Future<List<int>> pendingIds() async {
    final pending = await _plugin.pendingNotificationRequests();
    return pending.map((p) => p.id).toList();
  }
}