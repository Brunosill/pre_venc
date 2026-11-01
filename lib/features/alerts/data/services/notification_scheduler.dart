/// Interface que abstrai o agendamento — permite mock nos testes.
abstract class NotificationScheduler {
  Future<bool> scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  });

  Future<void> cancel(int id);
  Future<void> cancelAll();
}