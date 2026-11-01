import '../repositories/ocr_repository.dart';

class DeleteOcrResult {
  final OcrRepository repository;
  DeleteOcrResult(this.repository);

  Future<void> call(String id) => repository.deleteResult(id);
}