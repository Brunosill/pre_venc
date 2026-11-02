import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/hive_boxes.dart';
import '../../../product/data/models/inventory_item.dart';
import '../../../product/data/models/raw_product_data.dart';
import '../../../product/utils/product_parser.dart';

class FeedbackService {
  final SupabaseClient _client;
  FeedbackService(this._client);

  /// Envia o feedback (OCR + imagens + dados corrigidos) para o Supabase.
  Future<void> submit({
    required InventoryItem correctedItem,
    required ProductSuggestion originalSuggestion,
    required List<String> whatWasWrong, // ['name','lote','date']
  }) async {
    final raw = await _findLatestRawData(correctedItem.barcode);
    if (raw == null) {
      throw Exception('Captura original não encontrada no dispositivo.');
    }

    // 1. Upload das imagens anonimizadas
    String? image1Url;
    String? image2Url;
    try {
      if (raw.imagePath1 != null) {
        image1Url = await _uploadAnonymized(raw.imagePath1!, raw.id, 1);
      }
      if (raw.imagePath2 != null) {
        image2Url = await _uploadAnonymized(raw.imagePath2!, raw.id, 2);
      }
    } catch (e) {
      debugPrint('Falha no upload de imagens: $e');
      // Continua mesmo se falhar (feedback ainda é útil)
    }

    // 2. Inserir linha em raw_data_submissions
    await _client.from('raw_data_submissions').insert({
      'user_id': _client.auth.currentUser?.id,
      'barcode': correctedItem.barcode,
      'app_version': '1.0.0',
      'parser_version': '1.1.0',
      'ocr_text_1': _anonymizeText(raw.ocrText1),
      'ocr_text_2': _anonymizeText(raw.ocrText2),
      'image_1_url': image1Url,
      'image_2_url': image2Url,
      'corrected_name': correctedItem.name,
      'corrected_lote': correctedItem.lote,
      'corrected_manufacturing': _dateOnly(correctedItem.manufacturingDate),
      'corrected_expiration': _dateOnly(correctedItem.expirationDate),
      'source': 'feedback',
      'what_was_wrong': whatWasWrong.join(','),
    });
  }

  Future<RawProductData?> _findLatestRawData(String? barcode) async {
    if (barcode == null || barcode.isEmpty) return null;
    final box = HiveBoxes.rawProductBox;
    final matches =
        box.values.where((r) => r.barcode == barcode).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return matches.isEmpty ? null : matches.first;
  }

  Future<String?> _uploadAnonymized(
    String imagePath,
    String rawId,
    int index,
  ) async {
    final tempDir = await getTemporaryDirectory();
    final outputPath = '${tempDir.path}/anon_${rawId}_$index.jpg';

    // Recomprimir sem EXIF (remove GPS, data, câmera)
    final compressed = await FlutterImageCompress.compressAndGetFile(
      imagePath,
      outputPath,
      quality: 75,
      keepExif: false, // ← anonimização
    );
    if (compressed == null) return null;

    final bytes = await File(compressed.path).readAsBytes();
    final storagePath = 'submissions/$rawId/image_$index.jpg';

    await _client.storage.from('raw-submissions').uploadBinary(
          storagePath,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );

    return _client.storage.from('raw-submissions').getPublicUrl(storagePath);
  }

  /// Remove PII (e-mail, CPF, telefone, CEP) do texto OCR.
  String? _anonymizeText(String? text) {
    if (text == null) return null;
    var result = text;
    result = result.replaceAll(RegExp(r'\S+@\S+\.\S+'), '[EMAIL]');
    result = result.replaceAll(
        RegExp(r'\b\d{3}\.?\d{3}\.?\d{3}-?\d{2}\b'), '[CPF]');
    result = result.replaceAll(
        RegExp(r'\b\(?\d{2}\)?\s?\d{4,5}-?\d{4}\b'), '[TEL]');
    result = result.replaceAll(RegExp(r'\b\d{5}-?\d{3}\b'), '[CEP]');
    return result;
  }

  String? _dateOnly(DateTime? date) {
    if (date == null) return null;
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}