import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pre_venc/features/product/data/models/product_model.dart';

import '../../helpers/hive_test_helper.dart';

void main() {
  setUpAll(() async {
    Hive.registerAdapter(ProductModelAdapter());
    await HiveTestHelper.setUp();
  });

  tearDownAll(() async {
    await HiveTestHelper.tearDown();
  });

  test('serializa e desserializa todos os campos', () async {
    final box = await Hive.openBox<ProductModel>('products_test');
    final original = ProductModel(
      id: 'abc',
      name: 'Leite',
      barcode: '789123',
      manufacturingDate: DateTime(2026, 1, 1),
      expirationDate: DateTime(2026, 12, 31),
      imagePath: '/tmp/x.jpg',
      ocrText: 'texto ocr',
      createdAt: DateTime(2025, 6, 15),
      lote: 'L2024A',
      sourceIndex: 0,
    );

    await box.put(original.id, original);
    final read = box.get('abc');

    expect(read, isNotNull);
    expect(read!.name, 'Leite');
    expect(read.barcode, '789123');
    expect(read.lote, 'L2024A');
    expect(read.sourceIndex, 0);
    expect(read.expirationDate, DateTime(2026, 12, 31));

    await box.close();
  });

  test('aceita registros antigos sem lote/source', () async {
    final box = await Hive.openBox<ProductModel>('products_old_test');
    // Simula registro antigo (lote=null, sourceIndex default=2)
    final model = ProductModel(
      id: 'old',
      name: 'Antigo',
      createdAt: DateTime(2025),
    );
    await box.put('old', model);

    final read = box.get('old');
    expect(read!.lote, isNull);
    expect(read.sourceIndex, 2); // manual default

    await box.close();
  });
}
