import '../domain/entities/product.dart';

class ProductParser {
  // Datas — captura DD/MM/YYYY, DD/MM/YY, MM/YYYY, MM/YY
  static const _datePattern = r'(\d{1,2})[\/\-\.](\d{1,2})(?:[\/\-\.](\d{2,4}))?';

  static final _validadeRegex = RegExp(
    r'(?:VALIDADE|VENCIMENTO|VENC\.?|VAL\.?|VENCE|VÁLIDO ATÉ|CONSUMIR ATÉ)\s*[:\s]*' +
        _datePattern,
    caseSensitive: false,
  );

  static final _fabricacaoRegex = RegExp(
    r'(?:FABRICA[ÇC][ÃA]O|FAB\.?|FABRICADO EM|PRODUZIDO EM)\s*[:\s]*' +
        _datePattern,
    caseSensitive: false,
  );

  // Lote: aceita alfanumérico, hífen, ponto, barra (3-20 chars)
  static final _loteRegex = RegExp(
    r'(?:LOTE|LOT|L\.)\s*[:\sNºnº]*\s*([A-Z0-9][A-Z0-9\-\.\/]{2,20})',
    caseSensitive: false,
  );

  static final _barcodeRegex = RegExp(r'\b(\d{8,14})\b');

  /// Converte match de data em DateTime. Retorna null se inválido.
  static DateTime? _parseDateFromMatch(RegExpMatch match) {
    final p1 = int.tryParse(match.group(1)!);
    final p2 = int.tryParse(match.group(2)!);
    if (p1 == null || p2 == null) return null;

    final p3str = match.group(3);

    if (p3str != null) {
      // DD/MM/YYYY ou DD/MM/YY
      final p3 = int.tryParse(p3str);
      if (p3 == null) return null;
      final year = p3str.length == 2 ? 2000 + p3 : p3;
      if (p2 < 1 || p2 > 12 || p1 < 1 || p1 > 31) return null;
      try {
        return DateTime(year, p2, p1);
      } catch (_) {
        return null;
      }
    }

    // Apenas 2 campos: DD/MM ou MM/YY
    if (p1 > 12) {
      // DD/MM — assume ano atual ou próximo
      final now = DateTime.now();
      final year = p2 < now.month ? now.year + 1 : now.year;
      if (p1 < 1 || p1 > 31) return null;
      return DateTime(year, p2, p1);
    } else {
      // MM/YY — último dia do mês
      final year = p2 < 100 ? 2000 + p2 : p2;
      if (p1 < 1 || p1 > 12) return null;
      return DateTime(year, p1 + 1, 0); // dia 0 do próximo mês = último dia
    }
  }

  static DateTime? parseValidade(String text) {
    final match = _validadeRegex.firstMatch(text);
    return match == null ? null : _parseDateFromMatch(match);
  }

  static DateTime? parseFabricacao(String text) {
    final match = _fabricacaoRegex.firstMatch(text);
    return match == null ? null : _parseDateFromMatch(match);
  }

  static String? parseLote(String text) {
    final match = _loteRegex.firstMatch(text);
    final raw = match?.group(1)?.trim().toUpperCase();
    if (raw == null || raw.isEmpty) return null;
    // Filtra falsos positivos comuns
    if (raw == 'LOTE' || raw.length < 3) return null;
    return raw;
  }

  static String? parseBarcode(String text) {
    final match = _barcodeRegex.firstMatch(text);
    return match?.group(1);
  }

  static String? parseName(String text) {
    final lines = text.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.length < 3) continue;
      // Ignora linhas que são só números ou datas
      final letters = trimmed.replaceAll(RegExp(r'[^A-Za-zÀ-ÿ]'), '');
      if (letters.length >= 3 && letters.length != trimmed.length) {
        return trimmed.length > 60 ? trimmed.substring(0, 60) : trimmed;
      }
    }
    return null;
  }

  static ProductSuggestion parse(String ocrText) {
    return ProductSuggestion(
      name: parseName(ocrText),
      barcode: parseBarcode(ocrText),
      lote: parseLote(ocrText),
      manufacturingDate: parseFabricacao(ocrText),
      expirationDate: parseValidade(ocrText),
      source: ProductSource.ocr,
    );
  }
}

class ProductSuggestion {
  final String? name;
  final String? barcode;
  final String? lote;
  final DateTime? manufacturingDate;
  final DateTime? expirationDate;
  final ProductSource source;

  ProductSuggestion({
    this.name,
    this.barcode,
    this.lote,
    this.manufacturingDate,
    this.expirationDate,
    this.source = ProductSource.manual,
  });

  bool get hasAnyField =>
      name != null ||
      barcode != null ||
      lote != null ||
      manufacturingDate != null ||
      expirationDate != null;
}