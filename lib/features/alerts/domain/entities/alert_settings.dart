class AlertSettings {
  /// Dias antes do vencimento para disparar notificação.
  /// Padrão: [30, 1]
  final List<int> daysBefore;

  final bool enabled;

  const AlertSettings({
    this.daysBefore = const [30, 1],
    this.enabled = true,
  });

  AlertSettings copyWith({
    List<int>? daysBefore,
    bool? enabled,
  }) {
    return AlertSettings(
      daysBefore: daysBefore ?? this.daysBefore,
      enabled: enabled ?? this.enabled,
    );
  }

  List<int> get sortedDays {
    final copy = [...daysBefore]..sort((a, b) => b.compareTo(a));
    return copy;
  }
}
