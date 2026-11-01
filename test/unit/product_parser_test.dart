import 'package:flutter_test/flutter_test.dart';
import 'package:pre_venc/features/product/utils/product_parser.dart';

void main() {
  group('ProductParser - Validade', () {
    test('VALIDADE: 12/2027 (MM/YYYY) → último dia de dez/2027', () {
      final d = ProductParser.parseValidade('VALIDADE: 12/2027');
      expect(d, DateTime(2027, 12, 31));
    });

    test('V: 12/2027 (abreviação com 2 pontos)', () {
      final d = ProductParser.parseValidade('V: 12/2027');
      expect(d, DateTime(2027, 12, 31));
    });

    test('V 12 / 2027 (com espaços)', () {
      final d = ProductParser.parseValidade('V 12 / 2027');
      expect(d, DateTime(2027, 12, 31));
    });

    test('VENC 12/12/2027 (DD/MM/YYYY)', () {
      final d = ProductParser.parseValidade('VENC 12/12/2027');
      expect(d, DateTime(2027, 12, 12));
    });

    test('VÁLIDO ATÉ 10/11/2026', () {
      final d = ProductParser.parseValidade('VÁLIDO ATÉ 10/11/2026');
      expect(d, DateTime(2026, 11, 10));
    });

    test('Sem data de validade → null', () {
      expect(ProductParser.parseValidade('apenas texto qualquer'), isNull);
    });

    test('Data inválida (mês 13) → null', () {
      expect(ProductParser.parseValidade('VALIDADE 13/2027'), isNull);
    });
  });

  group('ProductParser - Fabricação', () {
    test('FAB: 10/2026 → último dia de out/2026', () {
      final d = ProductParser.parseFabricacao('FAB: 10/2026');
      expect(d, DateTime(2026, 10, 31));
    });

    test('F 10/2026 (abreviação)', () {
      final d = ProductParser.parseFabricacao('F 10/2026');
      expect(d, DateTime(2026, 10, 31));
    });

    test('FABRICAÇÃO 10/10/2026', () {
      final d = ProductParser.parseFabricacao('FABRICAÇÃO 10/10/2026');
      expect(d, DateTime(2026, 10, 10));
    });
  });

  group('ProductParser - Lote', () {
    test('LOTE: L2024A', () {
      expect(ProductParser.parseLote('LOTE: L2024A'), 'L2024A');
    });

    test('L: 2024A', () {
      expect(ProductParser.parseLote('L: 2024A'), '2024A');
    });

    test('Valor standalone L2024A', () {
      expect(ProductParser.parseLote('L2024A'), 'L2024A');
    });

    test('LEITE INTEGRAL não confunde com lote', () {
      expect(ProductParser.parseLote('LEITE INTEGRAL'), isNull);
    });

    test('LIMAO não confunde com lote', () {
      expect(ProductParser.parseLote('LIMAO'), isNull);
    });

    test('LOTE sem dígito é rejeitado', () {
      expect(ProductParser.parseLote('LOTE: ABCDEF'), isNull);
    });

    test('Sem lote → null', () {
      expect(ProductParser.parseLote('apenas texto'), isNull);
    });
  });

  group('ProductParser - Código de barras', () {
    test('EAN-13 de 13 dígitos', () {
      expect(
        ProductParser.parseBarcode('7891000315507'),
        '7891000315507',
      );
    });

    test('EAN-8', () {
      expect(ProductParser.parseBarcode('12345678'), '12345678');
    });

    test('Número com menos de 8 dígitos é ignorado', () {
      expect(ProductParser.parseBarcode('1234567'), isNull);
    });

    test('Número com 15 dígitos é ignorado', () {
      expect(ProductParser.parseBarcode('123456789012345'), isNull);
    });
  });

  group('ProductParser - Nome', () {
    test('Pega a primeira linha com 3+ letras', () {
      final text = '7891000315507\nLEITE NINHO\nVALIDADE 12/2027';
      expect(ProductParser.parseName(text), 'LEITE NINHO');
    });
  });

  group('ProductParser - parse completo', () {
    test('Extrai nome, lote, validade e código de uma vez', () {
      const text = '''
LEITE INTEGRAL NINHO
VALIDADE: 12/2027
LOTE: L2024A
7891000315507
''';
      final s = ProductParser.parse(text);
      expect(s.name, 'LEITE INTEGRAL NINHO');
      expect(s.lote, 'L2024A');
      expect(s.expirationDate, DateTime(2027, 12, 31));
      expect(s.barcode, '7891000315507');
      expect(s.hasAnyField, isTrue);
    });
  });
}