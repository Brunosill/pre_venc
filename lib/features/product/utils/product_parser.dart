import '../domain/entities/product.dart';

class ProductParser {
  // Data: DD/MM/YYYY, DD/MM/YY, MM/YYYY, MM/YY — com ou sem espaços, com ou sem dia
  static const _datePattern =
      r'(\d{1,2})\s*[\/\-\.]\s*(\d{4}|\d{1,2})(?:\s*[\/\-\.]\s*(\d{2,4}))?';

  // ==================== VALIDADE ====================
  // 1) Palavras completas
  static final _validadeFull = RegExp(
    r'(?:VALIDADE|VENCIMENTO|VENC\.?|VÁLIDO\s+ATÉ|CONSUMIR\s+ATÉ|VAL\.?)\s*[:\s\.\-]*\s*' +
        _datePattern,
    caseSensitive: false,
  );
  // 2) Abreviação "V" (precedida por início, espaço ou pontuação)
  static final _validadeShortV = RegExp(
    r'(?:^|[\s\(\[;,])(?:V|V\.)\s*[:\s\.]\s*' + _datePattern,
    caseSensitive: false,
  );

  // ==================== FABRICAÇÃO ====================
  static final _fabricacaoFull = RegExp(
    r'(?:FABRICA[ÇC][ÃA]O|FABRICADO\s+EM|PRODUZIDO\s+EM|FAB\.?|FABRIC\.?)\s*[:\s\.\-]*\s*' +
        _datePattern,
    caseSensitive: false,
  );
  static final _fabricacaoShortF = RegExp(
    r'(?:^|[\s\(\[;,])(?:F|F\.)\s*[:\s\.]\s*' + _datePattern,
    caseSensitive: false,
  );

  // ==================== LOTE ====================
  // 1) "LOTE"/"LOT" com valor alfanumérico
  static final _loteFull = RegExp(
    r'(?:LOTE|LOT\.?)\s*[:\sNºnº\.\-]*\s*([A-Z0-9][A-Z0-9\.\/\-]{2,20})',
    caseSensitive: false,
  );
  // 2) "L:" seguido de valor
  static final _loteShortL = RegExp(
    r'(?:^|[\s\(\[;,])(?:L|L\.)\s*[:\s\.]\s*([A-Z0-9][A-Z0-9\.\/\-]{2,20})',
    caseSensitive: false,
  );
  // 3) Valor começando com L seguido de alfanuméricos (padrão BR: L2024A, L-2024)
  static final _loteValueL = RegExp(
    r'\b(L[A-Z0-9\.\/\-]{3,19})\b',
    caseSensitive: false,
  );

  // ==================== CÓDIGO DE BARRAS ====================
  static final _barcodeRegex = RegExp(r'\b(\d{8,14})\b');

  // Palavras comuns que começam com L mas NÃO são lote
  static const _falseLoteWords = {
    'LEITE', 'LIMAO', 'LIMÃO', 'LARANJA', 'LEITE.', 'LIGHT', 'LATA',
    'LITRO', 'LITROS', 'LOTE', 'LOCAL', 'LINHA',
  };

  // ==================== HELPERS DE DATA ====================
  static DateTime? _parseDateFromMatch(RegExpMatch match) {
    final p1 = int.tryParse(match.group(1)!);
    final p2str = match.group(2)!;
    final p2 = int.tryParse(p2str);
    if (p1 == null || p2 == null) return null;

    final p3str = match.group(3);

    // DD/MM/YYYY ou DD/MM/YY (três campos)
    if (p3str != null) {
      final p3 = int.tryParse(p3str);
      if (p3 == null) return null;
      final year = p3str.length == 2 ? 2000 + p3 : p3;
      if (p1 < 1 || p1 > 31 || p2 < 1 || p2 > 12) return null;
      try {
        final d = DateTime(year, p2, p1);
        if (d.year != year || d.month != p2 || d.day != p1) return null;
        return d;
      } catch (_) {
        return null;
      }
    }

    // Dois campos: DD/MM ou MM/YY
    if (p1 > 12) {
      // DD/MM — usa ano atual ou próximo
      if (p2 < 1 || p2 > 12 || p1 < 1 || p1 > 31) return null;
      final now = DateTime.now();
      final year = p2 < now.month ? now.year + 1 : now.year;
      try {
        final d = DateTime(year, p2, p1);
        if (d.year != year || d.month != p2 || d.day != p1) return null;
        return d;
      } catch (_) {
        return null;
      }
    } else {
      // MM/YY (último dia do mês)
      if (p1 < 1 || p1 > 12) return null;
      final year = p2str.length == 4 ? p2 : (p2 < 100 ? 2000 + p2 : p2);
      try {
        return DateTime(year, p1 + 1, 0); // dia 0 do próximo mês = último dia
      } catch (_) {
        return null;
      }
    }
  }

  // ==================== PARSERS PÚBLICOS ====================
  static DateTime? parseValidade(String text) {
    final m1 = _validadeFull.firstMatch(text);
    if (m1 != null) {
      final d = _parseDateFromMatch(m1);
      if (d != null) return d;
    }
    final m2 = _validadeShortV.firstMatch(text);
    if (m2 != null) return _parseDateFromMatch(m2);
    return null;
  }

  static DateTime? parseFabricacao(String text) {
    final m1 = _fabricacaoFull.firstMatch(text);
    if (m1 != null) {
      final d = _parseDateFromMatch(m1);
      if (d != null) return d;
    }
    final m2 = _fabricacaoShortF.firstMatch(text);
    if (m2 != null) return _parseDateFromMatch(m2);
    return null;
  }

  static String? parseLote(String text) {
    // 1) LOTE/LOT
    final m1 = _loteFull.firstMatch(text);
    if (m1 != null) {
      final raw = m1.group(1)?.trim().toUpperCase();
      if (_isValidLote(raw)) return raw;
    }
    // 2) L: valor
    final m2 = _loteShortL.firstMatch(text);
    if (m2 != null) {
      final raw = m2.group(1)?.trim().toUpperCase();
      if (_isValidLote(raw)) return raw;
    }
    // 3) Valor standalone começando com L + dígitos
    final m3 = _loteValueL.firstMatch(text);
    if (m3 != null) {
      final raw = m3.group(1)?.trim().toUpperCase();
      if (_isValidLote(raw)) return raw;
    }
    return null;
  }

  static bool _isValidLote(String? raw) {
    if (raw == null) return false;
    if (raw.length < 4 || raw.length > 20) return false;
    if (_falseLoteWords.contains(raw)) return false;
    // Precisa conter pelo menos um dígito (evita falsos positivos como "LEITE")
    if (!RegExp(r'\d').hasMatch(raw)) return false;
    return true;
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

  /// Mescla duas sugestões, priorizando valores não-nulos da primeira.
  static ProductSuggestion merge(
    ProductSuggestion? base,
    ProductSuggestion next,
  ) {
    if (base == null) return next;
    return ProductSuggestion(
      name: base.name ?? next.name,
      barcode: base.barcode ?? next.barcode,
      lote: base.lote ?? next.lote,
      manufacturingDate: base.manufacturingDate ?? next.manufacturingDate,
      expirationDate: base.expirationDate ?? next.expirationDate,
      source: base.source,
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

  int get filledFields {
    var count = 0;
    if (name != null) count++;
    if (barcode != null) count++;
    if (lote != null) count++;
    if (manufacturingDate != null) count++;
    if (expirationDate != null) count++;
    return count;
  }
}
