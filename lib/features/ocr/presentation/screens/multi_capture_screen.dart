import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../product/data/models/raw_product_data.dart';
import '../../../product/domain/entities/product.dart';
import '../../../product/utils/product_parser.dart';
import '../../../../core/utils/hive_boxes.dart';
import '../../data/services/ocr_service.dart';

class CaptureResult {
  final ProductSuggestion suggestion;
  final String? rawId;
  final String? imagePath1;
  final String? imagePath2;
  final String? ocrText1;
  final String? ocrText2;

  CaptureResult({
    required this.suggestion,
    this.rawId,
    this.imagePath1,
    this.imagePath2,
    this.ocrText1,
    this.ocrText2,
  });
}

class MultiCaptureScreen extends ConsumerStatefulWidget {
  final String? barcode;
  const MultiCaptureScreen({super.key, this.barcode});

  @override
  ConsumerState<MultiCaptureScreen> createState() => _MultiCaptureScreenState();
}

class _MultiCaptureScreenState extends ConsumerState<MultiCaptureScreen> {
  final _picker = ImagePicker();
  final List<String> _paths = [];
  bool _processing = false;
  int _processed = 0;

  Future<void> _addImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (picked == null || !mounted) return;
    setState(() => _paths.add(picked.path));
  }

  void _removeImage(int index) {
    setState(() => _paths.removeAt(index));
  }

  Future<void> _processAll() async {
    if (_paths.isEmpty) return;
    setState(() {
      _processing = true;
      _processed = 0;
    });

    try {
      ProductSuggestion? merged;
      String? text1;
      String? text2;
      final ocrService = OcrService();

      for (var i = 0; i < _paths.length; i++) {
        try {
          final text = await ocrService.extractText(_paths[i]);
          if (i == 0) text1 = text;
          if (i == 1) text2 = text;

          final suggestion = ProductParser.parse(text);
          merged = ProductParser.merge(merged, suggestion);
        } catch (_) {
          // foto falhou, continua
        }
        if (mounted) setState(() => _processed = i + 1);
      }

      if (!mounted) return;

      // Salva evidência em RawProductData
      final rawId = const Uuid().v4();
      final raw = RawProductData(
        id: rawId,
        barcode: widget.barcode,
        imagePath1: _paths.isNotEmpty ? _paths[0] : null,
        imagePath2: _paths.length > 1 ? _paths[1] : null,
        ocrText1: text1,
        ocrText2: text2,
        createdAt: DateTime.now(),
        ocrStatus: 1,
      );
      await HiveBoxes.rawProductBox.put(rawId, raw);

      final result = CaptureResult(
        suggestion: merged ?? ProductSuggestion(source: ProductSource.ocr),
        rawId: rawId,
        imagePath1: raw.imagePath1,
        imagePath2: raw.imagePath2,
        ocrText1: text1,
        ocrText2: text2,
      );

      if (!mounted) return;
      Navigator.pop(context, result);
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _paths.isEmpty
              ? 'Capturar produto'
              : '${_paths.length} foto(s) capturada(s)',
        ),
        actions: [
          if (_paths.isNotEmpty)
            TextButton.icon(
              onPressed: _processAll,
              icon: const Icon(Icons.check),
              label: const Text('Processar'),
            ),
        ],
      ),
      body: _processing ? _buildProcessing() : _paths.isEmpty ? _buildEmpty() : _buildGrid(),
      bottomNavigationBar: _paths.isNotEmpty && !_processing
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _addImage(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Mais foto'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _processAll,
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('Processar'),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.document_scanner, size: 80, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            const Text(
              'Fotografe as informações',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDica('1️⃣', 'Frente', 'Nome do remédio/produto.'),
                  const SizedBox(height: 12),
                  _buildDica('2️⃣', 'Verso / Lateral', 'Validade, fabricação e lote (F, V, L).'),
                ],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _addImage(ImageSource.camera),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Tirar foto'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _addImage(ImageSource.gallery),
              icon: const Icon(Icons.photo_library),
              label: const Text('Escolher da galeria'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDica(String numero, String titulo, String descricao) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(numero, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(descricao, style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemCount: _paths.length,
      itemBuilder: (context, index) {
        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(File(_paths[index]), fit: BoxFit.cover),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => _removeImage(index),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.close, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProcessing() {
    final total = _paths.length;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(value: total > 0 ? _processed / total : null),
            const SizedBox(height: 24),
            Text(
              'Processando foto $_processed de $total...',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}