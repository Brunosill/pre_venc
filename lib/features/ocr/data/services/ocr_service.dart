import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';

/// Interface mantida igual à main:
/// extractText(String imagePath) → Future<String>
class OcrService {
  Future<String> extractText(String imagePath) async {
    try {
      final text = await FlutterTesseractOcr.extractText(
        imagePath,
        language: 'por',
      );
      return text.trim();
    } catch (e) {
      return '';
    }
  }

  void dispose() {}
}