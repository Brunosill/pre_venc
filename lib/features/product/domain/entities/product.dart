class Product {
  final String id;
  final String name;
  final String? barcode;
  final DateTime? manufacturingDate;
  final DateTime? expirationDate;
  final String? imagePath;
  final String? ocrText;
  final DateTime createdAt;

  Product({
    required this.id,
    required this.name,
    this.barcode,
    this.manufacturingDate,
    this.expirationDate,
    this.imagePath,
    this.ocrText,
    required this.createdAt,
  });

  /// Dias até o vencimento (negativo se já venceu).
  int? get daysToExpire {
    if (expirationDate == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final exp = DateTime(
        expirationDate!.year, expirationDate!.month, expirationDate!.day);
    return exp.difference(today).inDays;
  }

  bool get isExpired => (daysToExpire ?? 1) < 0;
  bool get isExpiringSoon =>
      daysToExpire != null && daysToExpire! >= 0 && daysToExpire! <= 7;
}