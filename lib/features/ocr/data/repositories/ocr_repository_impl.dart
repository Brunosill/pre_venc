import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:hive/hive.dart';

import '../../domain/entities/ocr_result.dart';
import '../../domain/repositories/ocr_repository.dart';
import '../models/ocr_result_model.dart';

class OcrRepositoryImpl implements OcrRepository {
  final Box<OcrResultModel> _box;
  final TextRecognizer _textRecognizer;

  OcrRepositoryImpl(this._box)
      : _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  @override
  Future<String> extractTextFromImage(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText =
          await _textRecognizer.processImage(inputImage);

      final buffer = StringBuffer();
      for (final block in recognizedText.blocks) {
        buffer.writeln(block.text);
        buffer.writeln();
      }

      final text = buffer.toString().trim();
      if (text.isEmpty) {
        throw Exception('Nenhum texto foi encontrado na imagem.');
      }
      return text;
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Erro ao processar imagem: $e');
    }
  }

  @override
  Future<void> saveResult(OcrResult result) async {
    final model = OcrResultModel(
      id: result.id,
      imagePath: result.imagePath,
      extractedText: result.extractedText,
      createdAt: result.createdAt,
      textLength: result.textLength,
    );
    await _box.put(model.id, model);
  }

  @override
  Future<List<OcrResult>> getHistory() async {
    final models = _box.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return models
        .map((m) => OcrResult(
              id: m.id,
              imagePath: m.imagePath,
              extractedText: m.extractedText,
              createdAt: m.createdAt,
              textLength: m.textLength,
            ))
        .toList();
  }

  @override
  Future<void> deleteResult(String id) async {
    await _box.delete(id);
  }

  @override
  Future<void> clearHistory() async {
    await _box.clear();
  }

  void dispose() {
    _textRecognizer.close();
  }
}