enum ProductSource { ocr, barcode, manual }

class Product {
  final String id;
  final String name;
  final String? barcode;
  final String? lote;
  final DateTime? manufacturingDate;
  final DateTime? expirationDate;
  final String? imagePath;
  final String? ocrText;
  final DateTime createdAt;
  final ProductSource source;

  Product({
    required this.id,
    required this.name,
    this.barcode,
    this.lote,
    this.manufacturingDate,
    this.expirationDate,
    this.imagePath,
    this.ocrText,
    required this.createdAt,
    this.source = ProductSource.manual,
  });

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

  String get sourceLabel {
    switch (source) {
      case ProductSource.ocr:
        return '📷 Foto (OCR)';
      case ProductSource.barcode:
        return '📊 Código de barras';
      case ProductSource.manual:
        return '✏️ Manual';
    }
  }
}