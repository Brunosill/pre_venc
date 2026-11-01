import 'package:flutter_test/flutter_test.dart';
import 'package:pre_venc/features/alerts/data/models/alert_settings_model.dart';
import 'package:pre_venc/features/alerts/data/services/alert_scheduler.dart';
import 'package:pre_venc/features/product/domain/entities/product.dart';

import '../helpers/fake_notification_scheduler.dart';

void main() {
  late FakeNotificationScheduler fakeNotifications;
  late AlertScheduler scheduler;

  setUp(() {
    fakeNotifications = FakeNotificationScheduler();
    scheduler = AlertScheduler(notifications: fakeNotifications);
  });

  Product buildProduct({
    required String id,
    required String name,
    DateTime? expiration,
  }) {
    return Product(
      id: id,
      name: name,
      expirationDate: expiration,
      createdAt: DateTime.now(),
    );
  }

  test('cancela todas as notificações antes de reagendar', () async {
    await scheduler.rescheduleAll(
      [],
      AlertSettingsModel(daysBefore: [30, 1], enabled: true),
    );
    expect(fakeNotifications.cancelAllCalled, isTrue);
  });

  test('não agenda nada se desabilitado', () async {
    await scheduler.rescheduleAll(
      [buildProduct(id: 'p1', name: 'Leite', expiration: DateTime(2026, 12, 31))],
      AlertSettingsModel(daysBefore: [30, 1], enabled: false),
    );
    expect(fakeNotifications.scheduled, isEmpty);
  });

  test('agenda notificações para cada daysBefore', () async {
    final future = DateTime.now().add(const Duration(days: 60));
    await scheduler.rescheduleAll(
      [buildProduct(id: 'p1', name: 'Leite', expiration: future)],
      AlertSettingsModel(daysBefore: [30, 1], enabled: true),
    );
    expect(fakeNotifications.scheduled, hasLength(2));
  });

  test('ignora produtos sem validade', () async {
    await scheduler.rescheduleAll(
      [buildProduct(id: 'p1', name: 'Sem validade')],
      AlertSettingsModel(daysBefore: [30], enabled: true),
    );
    expect(fakeNotifications.scheduled, isEmpty);
  });

  test('ignora notificações no passado', () async {
    final past = DateTime.now().subtract(const Duration(days: 10));
    await scheduler.rescheduleAll(
      [buildProduct(id: 'p1', name: 'Vencido', expiration: past)],
      AlertSettingsModel(daysBefore: [30], enabled: true),
    );
    expect(fakeNotifications.scheduled, isEmpty);
  });

  test('título e corpo contêm dados do produto', () async {
    final future = DateTime.now().add(const Duration(days: 10));
    await scheduler.rescheduleAll(
      [buildProduct(id: 'p1', name: 'Iogurte', expiration: future)],
      AlertSettingsModel(daysBefore: [5], enabled: true),
    );
    expect(fakeNotifications.scheduled, hasLength(1));
    final s = fakeNotifications.scheduled.first;
    expect(s['title'], contains('em 5 dias'));
    expect(s['body'], contains('Iogurte'));
  });

  test('notificationId é determinístico', () {
    final id1 = AlertScheduler.notificationId('abc', 30);
    final id2 = AlertScheduler.notificationId('abc', 30);
    expect(id1, id2);
  });

  test('notificationId difere por produto ou por diasBefore', () {
    final a = AlertScheduler.notificationId('produto1', 30);
    final b = AlertScheduler.notificationId('produto1', 1);
    final c = AlertScheduler.notificationId('produto2', 30);
    expect(a, isNot(equals(b)));
    expect(a, isNot(equals(c)));
  });
}