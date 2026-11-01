class ProductParser {
  /// Data de validade: "VALIDADE: 12/2027", "VENC 12/12/2027", "VENCIMENTO 12/27"...
  static final _validadeRegex = RegExp(
    r'(?:VALIDADE|VENCIMENTO|VENC\.?|VAL\.?)\s*[:\s]?\s*(\d{1,2})[\/\-\.](\d{1,2}|\d{4})',
    caseSensitive: false,
  );

  /// Data de fabricação: "FAB: 12/2026", "FABRICAÇÃO 12/12/2026"...
  static final _fabricacaoRegex = RegExp(
    r'(?:FABRICA[ÇC][ÃA]O|FAB\.?)\s*[:\s]?\s*(\d{1,2})[\/\-\.](\d{1,2}|\d{4})',
    caseSensitive: false,
  );

  /// Código de barras: 8–14 dígitos consecutivos.
  static final _barcodeRegex = RegExp(r'\b(\d{8,14})\b');

  static DateTime? parseDate(String text, RegExp pattern) {
    final match = pattern.firstMatch(text);
    if (match == null) return null;

    final part1 = int.tryParse(match.group(1)!);
    final part2Raw = match.group(2)!;
    final part2 = int.tryParse(part2Raw);
    if (part1 == null || part2 == null) return null;

    // Se o segundo campo tem 4 dígitos, é ano. Senão, é mês (MM/AAAA).
    int month, year;
    if (part2Raw.length == 4) {
      month = part1;
      year = part2;
    } else {
      // Formato DD/MM (assume o ano atual; se mês já passou, próximo ano)
      month = part2;
      year = DateTime.now().year;
      final now = DateTime.now();
      if (month < now.month) year += 1;
    }

    if (month < 1 || month > 12) return null;
    return DateTime(year, month, 1);
  }

  static DateTime? parseValidade(String text) =>
      parseDate(text, _validadeRegex);

  static DateTime? parseFabricacao(String text) =>
      parseDate(text, _fabricacaoRegex);

  static String? parseBarcode(String text) {
    final match = _barcodeRegex.firstMatch(text);
    return match?.group(1);
  }

  /// Nome: primeira linha com pelo menos 3 caracteres alfabéticos.
  static String? parseName(String text) {
    final lines = text.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.length < 3) continue;
      final letters = trimmed.replaceAll(RegExp(r'[^A-Za-zÀ-ÿ]'), '');
      if (letters.length >= 3) {
        // Limita a 60 caracteres para evitar linhas muito longas
        return trimmed.length > 60 ? trimmed.substring(0, 60) : trimmed;
      }
    }
    return null;
  }

  /// Aplica todos os parsers de uma vez.
  static ProductSuggestion parse(String ocrText) {
    return ProductSuggestion(
      name: parseName(ocrText),
      barcode: parseBarcode(ocrText),
      manufacturingDate: parseFabricacao(ocrText),
      expirationDate: parseValidade(ocrText),
    );
  }
}

class ProductSuggestion {
  final String? name;
  final String? barcode;
  final DateTime? manufacturingDate;
  final DateTime? expirationDate;

  ProductSuggestion({
    this.name,
    this.barcode,
    this.manufacturingDate,
    this.expirationDate,
  });

  bool get hasAnyField =>
      name != null ||
      barcode != null ||
      manufacturingDate != null ||
      expirationDate != null;
}