import 'package:flutter_test/flutter_test.dart';
import 'package:pre_venc/features/product/utils/product_parser.dart';

void main() {
  group('ProductParser - Validade', () {
    test('VALIDADE: 12/2027 (MM/YYYY) → primeiro dia de dez/2027', () {
      final d = ProductParser.parseValidade('VALIDADE: 12/2027');
      expect(d, DateTime(2027, 12, 1));
    });

    test('V: 12/2027 (abreviação com 2 pontos)', () {
      final d = ProductParser.parseValidade('V: 12/2027');
      expect(d, DateTime(2027, 12, 1));
    });

    test('V 12 / 2027 (com espaços)', () {
      final d = ProductParser.parseValidade('V 12 / 2027');
      expect(d, DateTime(2027, 12, 1));
    });

    test('VENC 12/12/2027 (DD/MM/YYYY)', () {
      final d = ProductParser.parseValidade('VENC 12/12/2027');
      expect(d, DateTime(2027, 12, 12));
    });
  });

  group('ProductParser - Fabricação', () {
    test('FAB: 10/2026 → primeiro dia de out/2026', () {
      final d = ProductParser.parseFabricacao('FAB: 10/2026');
      expect(d, DateTime(2026, 10, 1));
    });

    test('F 10/2026 (abreviação)', () {
      final d = ProductParser.parseFabricacao('F 10/2026');
      expect(d, DateTime(2026, 10, 1));
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

    test('L 5M5707 (espaçado)', () {
      expect(ProductParser.parseLote('L 5M5707'), '5M5707');
    });
  });

  group('ProductParser - Imagens Reais (Medicamentos)', () {
    test('F 0 5  2 6 (pontilhado) deve virar 01/05/2026', () {
      final d = ProductParser.parseFabricacao('F 0 5  2 6');
      expect(d, DateTime(2026, 5, 1));
    });

    test('V 0 5  2 8 (pontilhado) deve virar 01/05/2028', () {
      final d = ProductParser.parseValidade('V 0 5  2 8');
      expect(d, DateTime(2028, 5, 1));
    });

    test('F05/2026 V05/2028 na mesma linha', () {
      final text = 'L565580\nF05/2026 V05/2028';
      expect(ProductParser.parseFabricacao(text), DateTime(2026, 5, 1));
      expect(ProductParser.parseValidade(text), DateTime(2028, 5, 1));
    });

    test('Deve ignorar "PROIBIDA A VENDA" e pegar "metildopa"', () {
      const text = 'EMS\nmetildopa\n250 mg\nPROIBIDA A VENDA\nComprimido revestido\nUSO ORAL';
      expect(ProductParser.parseName(text), 'metildopa');
    });

    test('Deve ignorar bula longa e pegar "Myrafer"', () {
      const text = 'myralis\nMyrafer\nferripolimaltose\n100 mg\n400 mg de ferripolimaltose, equivalente a 100 mg de ferro elementar\nAMOSTRA GRÁTIS';
      expect(ProductParser.parseName(text), 'Myrafer');
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
      expect(s.expirationDate, DateTime(2027, 12, 1));
      expect(s.barcode, '7891000315507');
    });
  });
}