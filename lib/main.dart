import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/utils/hive_boxes.dart';
import 'features/alerts/data/models/alert_settings_model.dart';
import 'features/alerts/data/services/notification_service.dart';
import 'features/ocr/data/models/ocr_result_model.dart';
import 'features/product/data/models/barcode_cache_model.dart';
import 'features/product/data/models/product_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  Hive.registerAdapter(OcrResultModelAdapter());
  Hive.registerAdapter(ProductModelAdapter());
  Hive.registerAdapter(BarcodeCacheModelAdapter());
  Hive.registerAdapter(AlertSettingsModelAdapter());

  await HiveBoxes.init();
  await NotificationService.init();

  // Inicializa Supabase apenas se as credenciais foram passadas
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  if (supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty) {
    try {
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
      debugPrint('Supabase inicializado');
    } catch (e) {
      debugPrint('Supabase NÃO inicializado: $e');
    }
  } else {
    debugPrint('Supabase não configurado — app funciona 100% offline');
  }

  runApp(const ProviderScope(child: PreVencApp()));
}
