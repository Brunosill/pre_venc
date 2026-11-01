import 'package:hive/hive.dart';
import '../../features/alerts/data/models/alert_settings_model.dart';
import '../../features/ocr/data/models/ocr_result_model.dart';
import '../../features/product/data/models/product_model.dart';

class HiveBoxes {
  static const String ocrResults = 'ocr_results';
  static const String products = 'products';
  static const String alertSettings = 'alert_settings';

  static late Box<OcrResultModel> ocrResultBox;
  static late Box<ProductModel> productBox;
  static late Box<AlertSettingsModel> alertSettingsBox;

  static Future<void> init() async {
    ocrResultBox = await Hive.openBox<OcrResultModel>(ocrResults);
    productBox = await Hive.openBox<ProductModel>(products);
    alertSettingsBox = await Hive.openBox<AlertSettingsModel>(alertSettings);
  }
}
