import 'dart:io';
import 'package:hive/hive.dart';

class HiveTestHelper {
  static late Directory tempDir;

  static Future<void> setUp() async {
    tempDir = await Directory.systemTemp.createTemp('pre_venc_test_');
    Hive.init(tempDir.path);
  }

  static Future<void> tearDown() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  }
}