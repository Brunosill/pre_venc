import '../domain/entities/product.dart';

class ProductParser {
  // ==================== BLACKLIST DE NOME ====================
  static const _nameBlacklist = {
    'PROIBIDA', 'VENDA', 'USO', 'ORAL', 'ADULTO', 'INFANTIL', 'ANOS', 'ACIMA',
    'AMOSTRA', 'GRATIS', 'GRÁTIS', 'PRESCRIÇÃO', 'PRESCRICAO', 'SOB',
    'GENÉRICO', 'GENERICO', 'COMPRIMIDO', 'COMPRIMIDOS', 'REVESTIDO',
    'CONTÉM', 'CONTEM', 'MEDICAMENTO', 'FABRICADO', 'PRODUZIDO',
    'LOTE', 'VALIDADE', 'FAB', 'VENC', 'EQUIVALENTE', 'FERRO', 'ELEMENTAR',
  };

  // ==================== PADRÃO DE DATA ====================
  static const _datePattern =
      r'(\d{1,2})\s*[\/\-\.\s]?\s*(\d{4}|\d{2})(?:\s*[\/\-\.\s]?\s*(\d{2,4}))?';

  // ==================== VALIDADE ====================
  static final _validadeRegex = RegExp(
    r'(?:VALIDADE|VENCIMENTO|VENC\.?|VÁLIDO\s+ATÉ|CONSUMIR\s+ATÉ|VAL\.?|V|V\.)\s*[:\s\.\-]*\s*' +
        _datePattern,
    caseSensitive: false,
  );

  // ==================== FABRICAÇÃO ====================
  static final _fabricacaoRegex = RegExp(
    r'(?:FABRICA[ÇC][ÃA]O|FABRICADO\s+EM|PRODUZIDO\s+EM|FAB\.?|F|F\.)\s*[:\s\.\-]*\s*' +
        _datePattern,
    caseSensitive: false,
  );

  // ==================== LOTE ====================
  static final _loteRegex = RegExp(
    r'(?:LOTE|LOT\.?|L(?!\d))\s*[:\sNºnº\.\-]*\s*([A-Z0-9][A-Z0-9\.\/\-]{2,20})|(L[0-9][A-Z0-9\.\/\-]{2,19})',
    caseSensitive: false,
  );

  static final _barcodeRegex = RegExp(r'\b(\d{8,14})\b');

  // ==================== SANITIZAÇÃO (APENAS PARA DATAS) ====================
  /// Corrige as bagunças que o OCR faz apenas nas datas (letras F e V)
  static String _sanitizeDates(String text) {
    var result = text.toUpperCase();

    // 1. Troca O/Q por 0 apenas se estiver logo após F ou V
    result = result.replaceAll(RegExp(r'(?<=[FV])\s*[OQ]\s*'), '0');
    // 2. Troca I/L por 1 e S por 5 apenas se estiver entre números
    result = result.replaceAll(RegExp(r'(?<=\d)\s*[OQ]\s*(?=\d)'), '0');
    result = result.replaceAll(RegExp(r'(?<=\d)\s*[IL]\s*(?=\d)'), '1');
    result = result.replaceAll(RegExp(r'(?<=\d)\s*S\s*(?=\d)'), '5');

    var prev = '';
    while (result != prev) {
      prev = result;
      // Junta "F 05" -> "F05" (usando [ \t]+ para não pular linha)
      result = result.replaceAllMapped(RegExp(r'([FV])[ \t]+(\d)'), (m) => '${m[1]}${m[2]}');
      // Junta "0 5 2 6" -> "0526"
      result = result.replaceAllMapped(RegExp(r'(\d)[ \t]+(\d)'), (m) => '${m[1]}${m[2]}');
    }
    return result;
  }

  // ==================== HELPERS DE DATA ====================
  static DateTime? _parseDateFromMatch(RegExpMatch match) {
    final p1 = int.tryParse(match.group(1)!);
    final p2str = match.group(2)!;
    final p2 = int.tryParse(p2str);
    if (p1 == null || p2 == null) return null;

    final p3str = match.group(3);

    // 3 partes: DD/MM/YYYY
    if (p3str != null) {
      final p3 = int.tryParse(p3str);
      if (p3 == null) return null;
      final year = p3str.length == 2 ? 2000 + p3 : p3;
      if (p1 < 1 || p1 > 31 || p2 < 1 || p2 > 12) return null;
      return DateTime(year, p2, p1);
    }

    // 2 partes, p2 tem 4 dígitos: MM/YYYY
    // REGRA ANVISA: Vence no primeiro dia do mês
    if (p2str.length == 4) {
      if (p1 < 1 || p1 > 12) return null;
      return DateTime(p2, p1, 1);
    }

    // 2 partes, p1 > 12: DD/MM
    if (p1 > 12) {
      if (p1 < 1 || p1 > 31 || p2 < 1 || p2 > 12) return null;
      final now = DateTime.now();
      final year = p2 < now.month ? now.year + 1 : now.year;
      return DateTime(year, p2, p1);
    }

    // 2 partes, p1 <= 12: MM/YY
    // REGRA ANVISA: Vence no primeiro dia do mês
    if (p1 < 1 || p1 > 12) return null;
    final year = p2 < 100 ? 2000 + p2 : p2;
    return DateTime(year, p1, 1);
  }

  // ==================== PARSERS PÚBLICOS ====================
  static DateTime? parseValidade(String text) {
    final m = _validadeRegex.firstMatch(_sanitizeDates(text));
    return m == null ? null : _parseDateFromMatch(m);
  }

  static DateTime? parseFabricacao(String text) {
    final m = _fabricacaoRegex.firstMatch(_sanitizeDates(text));
    return m == null ? null : _parseDateFromMatch(m);
  }

  static String? parseLote(String text) {
    // O lote NÃO usa sanitização, ele lê o texto original puro
    final matches = _loteRegex.allMatches(text);
    for (final m in matches) {
      final raw = (m.group(1) ?? m.group(2))?.trim().toUpperCase();
      if (raw == null || raw.length < 4) continue;
      if (!RegExp(r'\d').hasMatch(raw)) continue;
      return raw;
    }
    return null;
  }

  static String? parseBarcode(String text) {
    final m = _barcodeRegex.firstMatch(text);
    return m?.group(1);
  }

  static String? parseName(String text) {
    final candidates = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.length >= 4 && l.length <= 40)
        .where((l) => !RegExp(r'^\d').hasMatch(l))
        .where((l) => l.split(' ').length <= 4)
        .where((l) {
      final upper = l.toUpperCase();
      return !_nameBlacklist.any((w) => upper.contains(w));
    })
        .where((l) {
      final letters = l.replaceAll(RegExp(r'[^A-Za-zÀ-ÿ]'), '');
      return letters.length >= 3;
    })
        .toList();

    if (candidates.isEmpty) return null;

    int score(String s) {
      int base = s.length;
      final titleCase = RegExp(r'^[A-ZÀ-Ý][a-zà-ÿ]').hasMatch(s);
      final hasMidCaps = RegExp(r'[a-zà-ÿ][A-ZÀ-Ý]').hasMatch(s);
      if (titleCase && !hasMidCaps) base += 50;
      if (s.isNotEmpty && s[0].toUpperCase() == s[0]) base += 10;
      return base;
    }

    candidates.sort((a, b) => score(b).compareTo(score(a)));
    final best = candidates.first;
    return best.length > 60 ? best.substring(0, 60) : best;
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

  static ProductSuggestion merge(ProductSuggestion? base, ProductSuggestion next) {
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
      name != null || barcode != null || lote != null || manufacturingDate != null || expirationDate != null;

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