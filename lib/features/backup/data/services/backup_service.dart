import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utils/hive_boxes.dart';
import '../../../product/data/models/inventory_item.dart';
import '../../../product/data/models/raw_product_data.dart';

class BackupService {
  Future<File> exportBackup() async {
    final tempDir = await getTemporaryDirectory();
    final backupDir = Directory('${tempDir.path}/backup_temp');
    if (backupDir.existsSync()) backupDir.deleteSync(recursive: true);
    backupDir.createSync(recursive: true);

    final imagesDir = Directory('${backupDir.path}/images');
    imagesDir.createSync(recursive: true);

    // 1. Serializar Dados
    final inventoryItems = HiveBoxes.inventoryItemBox.values.map((e) => e.toJson()).toList();
    final rawProducts = HiveBoxes.rawProductBox.values.map((e) => e.toJson()).toList();

    File('${backupDir.path}/inventory_items.json').writeAsStringSync(jsonEncode(inventoryItems));
    File('${backupDir.path}/raw_products.json').writeAsStringSync(jsonEncode(rawProducts));

    // 2. Copiar Imagens
    final imagePaths = <String>[];
    for (final raw in HiveBoxes.rawProductBox.values) {
      if (raw.imagePath1 != null) imagePaths.add(raw.imagePath1!);
      if (raw.imagePath2 != null) imagePaths.add(raw.imagePath2!);
    }

    for (final path in imagePaths) {
      final file = File(path);
      if (file.existsSync()) {
        final fileName = path.split('/').last;
        file.copySync('${imagesDir.path}/$fileName');
      }
    }

    // 3. Manifesto
    final manifest = {
      'version': 1,
      'app_version': '1.0.0',
      'created_at': DateTime.now().toIso8601String(),
      'counts': {
        'inventory_items': inventoryItems.length,
        'raw_products': rawProducts.length,
        'images': imagePaths.length,
      }
    };
    File('${backupDir.path}/manifest.json').writeAsStringSync(jsonEncode(manifest));

    // 4. Compactar
    final zipPath = '${tempDir.path}/prevenc_backup_${DateTime.now().millisecondsSinceEpoch}.pvbackup';
    final encoder = ZipFileEncoder();
    encoder.create(zipPath);
    await encoder.addDirectory(backupDir, includeDirName: false);
    await encoder.close();

    return File(zipPath);
  }

  Future<void> importBackup(File zipFile, {required bool merge}) async {
    final tempDir = await getTemporaryDirectory();
    final extractDir = Directory('${tempDir.path}/backup_extract_${const Uuid().v4()}');
    extractDir.createSync(recursive: true);

    // 1. Descompactar
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    for (final file in archive) {
      final filename = '${extractDir.path}/${file.name}';
      if (file.isFile) {
        final data = file.content as List<int>;
        File(filename).createSync(recursive: true);
        File(filename).writeAsBytesSync(data);
      } else {
        Directory(filename).createSync(recursive: true);
      }
    }

    // 2. Validar Manifesto
    final manifestFile = File('${extractDir.path}/manifest.json');
    if (!manifestFile.existsSync()) throw Exception('Arquivo de backup inválido (manifesto ausente).');
    final manifest = jsonDecode(manifestFile.readAsStringSync());
    if (manifest['version'] > 1) throw Exception('Atualize seu aplicativo para abrir este backup.');

    if (!merge) {
      await HiveBoxes.inventoryItemBox.clear();
      await HiveBoxes.rawProductBox.clear();
    }

    // 3. Restaurar Imagens
    final imagesDir = Directory('${extractDir.path}/images');
    final appDir = await getApplicationDocumentsDirectory();
    final finalImagesDir = Directory('${appDir.path}/images');
    if (!finalImagesDir.existsSync()) finalImagesDir.createSync(recursive: true);

    if (imagesDir.existsSync()) {
      for (final file in imagesDir.listSync()) {
        if (file is File) {
          final fileName = file.path.split('/').last;
          file.copySync('${finalImagesDir.path}/$fileName');
        }
      }
    }

    // 4. Restaurar Dados
    final invFile = File('${extractDir.path}/inventory_items.json');
    if (invFile.existsSync()) {
      final list = jsonDecode(invFile.readAsStringSync()) as List;
      for (final json in list) {
        final item = InventoryItem.fromJson(json);
        await HiveBoxes.inventoryItemBox.put(item.id, item);
      }
    }

    final rawFile = File('${extractDir.path}/raw_products.json');
    if (rawFile.existsSync()) {
      final list = jsonDecode(rawFile.readAsStringSync()) as List;
      for (final json in list) {
        final raw = RawProductData.fromJson(json, finalImagesDir.path);
        await HiveBoxes.rawProductBox.put(raw.id, raw);
      }
    }

    extractDir.deleteSync(recursive: true);
  }
}