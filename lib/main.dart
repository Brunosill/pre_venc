import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'core/utils/hive_boxes.dart';
import 'features/alerts/data/models/alert_settings_model.dart';
import 'features/alerts/data/services/notification_service.dart';
import 'features/ocr/data/models/ocr_result_model.dart';
import 'features/product/data/models/product_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  Hive.registerAdapter(OcrResultModelAdapter());
  Hive.registerAdapter(ProductModelAdapter());
  Hive.registerAdapter(AlertSettingsModelAdapter());

  await HiveBoxes.init();
  await NotificationService.init();

  runApp(const ProviderScope(child: PreVencApp()));
}
