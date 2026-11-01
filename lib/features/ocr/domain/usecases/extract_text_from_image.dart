import '../repositories/ocr_repository.dart';

class ExtractTextFromImage {
  final OcrRepository repository;
  ExtractTextFromImage(this.repository);

  Future<String> call(String imagePath) =>
      repository.extractTextFromImage(imagePath);
}