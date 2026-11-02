import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/utils/hive_boxes.dart';
import 'features/alerts/data/models/alert_settings_model.dart';
import 'features/alerts/data/services/notification_service.dart';

import 'features/product/data/models/barcode_cache_model.dart';
import 'features/product/data/models/inventory_item.dart';
import 'features/product/data/models/raw_product_data.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  // Registrando os novos adapters
  Hive.registerAdapter(RawProductDataAdapter());
  Hive.registerAdapter(InventoryItemAdapter());
  Hive.registerAdapter(BarcodeCacheModelAdapter());
  Hive.registerAdapter(AlertSettingsModelAdapter());

  await HiveBoxes.init();
  await NotificationService.init();

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  if (supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty) {
  try {
    // ignore: deprecated_member_use
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
    // ignore: deprecated_member_use
    debugPrint('Supabase inicializado');
  } catch (e) {
    debugPrint('Supabase NÃO inicializado: $e');
  }
}

  runApp(const ProviderScope(child: PreVencApp()));
}
