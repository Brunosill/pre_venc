import '../entities/ocr_result.dart';
import '../repositories/ocr_repository.dart';

class GetOcrHistory {
  final OcrRepository repository;
  GetOcrHistory(this.repository);

  Future<List<OcrResult>> call() => repository.getHistory();
}