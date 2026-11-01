import '../entities/ocr_result.dart';
import '../repositories/ocr_repository.dart';

class SaveOcrResult {
  final OcrRepository repository;
  SaveOcrResult(this.repository);

  Future<void> call(OcrResult result) => repository.saveResult(result);
}