import 'package:flutter_test/flutter_test.dart';
import 'package:pre_venc/features/ocr/data/models/ocr_result_model.dart';

void main() {
  test('Adapter serializa e desserializa corretamente', () {
    final model = OcrResultModel(
      id: 'abc-123',
      imagePath: '/tmp/img.jpg',
      extractedText: 'Olá mundo',
      createdAt: DateTime(2026, 11, 1),
      textLength: 9,
    );

    expect(model.id, 'abc-123');
    expect(model.extractedText, 'Olá mundo');
    expect(model.textLength, 9);
  });
}
