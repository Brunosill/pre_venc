import '../entities/ocr_result.dart';

abstract class OcrRepository {
  Future<String> extractTextFromImage(String imagePath);
  Future<void> saveResult(OcrResult result);
  Future<List<OcrResult>> getHistory();
  Future<void> deleteResult(String id);
  Future<void> clearHistory();
}