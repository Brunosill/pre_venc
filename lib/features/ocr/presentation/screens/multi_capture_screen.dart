import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../product/domain/entities/product.dart';
import '../../../product/presentation/screens/product_form_screen.dart';
import '../../../product/utils/product_parser.dart';
import '../providers/ocr_providers.dart';

class MultiCaptureScreen extends ConsumerStatefulWidget {
  final bool useCameraFirst;

  const MultiCaptureScreen({super.key, this.useCameraFirst = false});

  @override
  ConsumerState<MultiCaptureScreen> createState() =>
      _MultiCaptureScreenState();
}

class _MultiCaptureScreenState extends ConsumerState<MultiCaptureScreen> {
  final _picker = ImagePicker();
  final List<String> _paths = [];
  bool _processing = false;
  int _processed = 0;

  Future<void> _addImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 95,
      maxWidth: 2000,
    );
    if (picked == null || !mounted) return;
    setState(() => _paths.add(picked.path));
  }

  Future<void> _addFromCamera() => _addImage(ImageSource.camera);
  Future<void> _addFromGallery() => _addImage(ImageSource.gallery);

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
      // Mescla os dados de cada foto
      String? name;
      String? barcode;
      String? lote;
      DateTime? fabrication;
      DateTime? expiration;
      final allTexts = <String>[];

      final extractText = ref.read(extractTextProvider);

      for (var i = 0; i < _paths.length; i++) {
        try {
          final text = await extractText(_paths[i]);
          allTexts.add(text);

          final suggestion = ProductParser.parse(text);
          name ??= suggestion.name;
          barcode ??= suggestion.barcode;
          lote ??= suggestion.lote;
          fabrication ??= suggestion.manufacturingDate;
          expiration ??= suggestion.expirationDate;
        } catch (_) {
          // Se uma foto falhar, continua com as outras
        }
        if (mounted) setState(() => _processed = i + 1);
      }

      if (!mounted) return;

      final mergedText = allTexts.join('\n\n---\n\n');
      final finalSuggestion = ProductSuggestion(
        name: name,
        barcode: barcode,
        lote: lote,
        manufacturingDate: fabrication,
        expirationDate: expiration,
        source: ProductSource.ocr,
      );

      if (finalSuggestion.hasAnyField) {
        // Tem dados → abre o form pré-preenchido
        final ok = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => ProductFormScreen(
              suggestion: finalSuggestion,
              imagePath: _paths.first,
              ocrText: mergedText,
            ),
          ),
        );
        if (ok == true && mounted) {
          Navigator.pop(context); // volta à lista de produtos
        }
      } else {
        // Nenhum campo reconhecido → abre form manual com texto
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductFormScreen(
              imagePath: _paths.first,
              ocrText: mergedText,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showCameraFirst = widget.useCameraFirst && _paths.isEmpty;

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
      body: _processing
          ? _buildProcessing()
          : _paths.isEmpty
              ? _buildEmpty(showCameraFirst)
              : _buildGrid(),
      bottomNavigationBar: _paths.isNotEmpty && !_processing
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _addFromCamera,
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

  Widget _buildEmpty(bool cameraFirst) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 96,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            const Text(
              'Fotografe as partes do produto',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Tire fotos da frente (nome), do verso (validade/lote) '
              'e de qualquer código de barras. O app vai combinar as informações.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _addFromCamera,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Tirar foto'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _addFromGallery,
              icon: const Icon(Icons.photo_library),
              label: const Text('Escolher da galeria'),
            ),
          ],
        ),
      ),
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
              child: Image.file(
                File(_paths[index]),
                fit: BoxFit.cover,
              ),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
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
            CircularProgressIndicator(
              value: total > 0 ? _processed / total : null,
            ),
            const SizedBox(height: 24),
            Text(
              'Processando foto $_processed de $total...',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Extraindo texto e combinando informações',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}