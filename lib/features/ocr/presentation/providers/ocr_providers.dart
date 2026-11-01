import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../../../core/utils/hive_boxes.dart';
import '../../data/models/ocr_result_model.dart';
import '../../data/repositories/ocr_repository_impl.dart';
import '../../domain/entities/ocr_result.dart';
import '../../domain/repositories/ocr_repository.dart';
import '../../domain/usecases/delete_ocr_result.dart';
import '../../domain/usecases/extract_text_from_image.dart';
import '../../domain/usecases/get_ocr_history.dart';
import '../../domain/usecases/save_ocr_result.dart';

// Box do Hive (já inicializada no main.dart)
final ocrBoxProvider = Provider<Box<OcrResultModel>>(
  (ref) => HiveBoxes.ocrResultBox,
);

// Repositório — libera o TextRecognizer no dispose
final ocrRepositoryProvider = Provider<OcrRepository>((ref) {
  final box = ref.watch(ocrBoxProvider);
  final repo = OcrRepositoryImpl(box);
  ref.onDispose(() => repo.dispose());
  return repo;
});

// Casos de uso
final extractTextProvider = Provider<ExtractTextFromImage>((ref) {
  return ExtractTextFromImage(ref.watch(ocrRepositoryProvider));
});

final saveOcrResultProvider = Provider<SaveOcrResult>((ref) {
  return SaveOcrResult(ref.watch(ocrRepositoryProvider));
});

final getOcrHistoryProvider = Provider<GetOcrHistory>((ref) {
  return GetOcrHistory(ref.watch(ocrRepositoryProvider));
});

final deleteOcrResultProvider = Provider<DeleteOcrResult>((ref) {
  return DeleteOcrResult(ref.watch(ocrRepositoryProvider));
});

// Stream reativo do histórico (atualiza a HomeScreen automaticamente)
final ocrHistoryProvider = StreamProvider<List<OcrResult>>((ref) async* {
  final box = ref.watch(ocrBoxProvider);
  yield _mapBox(box);
  await for (final _ in box.watch()) {
    yield _mapBox(box);
  }
});

List<OcrResult> _mapBox(Box<OcrResultModel> box) {
  final models = box.values.toList()
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