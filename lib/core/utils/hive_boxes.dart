import 'package:hive/hive.dart';
import '../../features/ocr/data/models/ocr_result_model.dart';

class HiveBoxes {
  static const String ocrResults = 'ocr_results';
  static late Box<OcrResultModel> ocrResultBox;

  static Future<void> init() async {
    ocrResultBox = await Hive.openBox<OcrResultModel>(ocrResults);
  }
}
