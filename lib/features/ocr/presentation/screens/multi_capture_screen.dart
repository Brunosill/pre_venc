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

  /// Dados já obtidos da API de código de barras (nome, marca, categoria).
  /// O OCR mescla esses dados com o que conseguir extrair das fotos.
  final ProductSuggestion? initialSuggestion;

  const MultiCaptureScreen({
    super.key,
    this.useCameraFirst = false,
    this.initialSuggestion,
  });

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
      // Começa com o que já veio da API de código de barras
      ProductSuggestion? merged = widget.initialSuggestion;
      final allTexts = <String>[];

      final extractText = ref.read(extractTextProvider);

      for (var i = 0; i < _paths.length; i++) {
        try {
          final text = await extractText(_paths[i]);
          allTexts.add(text);
          final suggestion = ProductParser.parse(text);
          merged = ProductParser.merge(merged, suggestion);
        } catch (_) {
          // foto falhou, continua com as demais
        }
        if (mounted) setState(() => _processed = i + 1);
      }

      if (!mounted) return;

      final mergedText = allTexts.join('\n\n---\n\n');

      if (merged == null) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductFormScreen(
              imagePath: _paths.first,
              ocrText: mergedText,
            ),
          ),
        );
        return;
      }

      final proceed = await _showReviewDialog(merged);
      if (proceed != true || !mounted) return;

      final ok = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ProductFormScreen(
            suggestion: merged,
            imagePath: _paths.first,
            ocrText: mergedText,
          ),
        ),
      );

      if (ok == true && mounted) {
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<bool?> _showReviewDialog(ProductSuggestion s) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Dados extraídos'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Confira os dados antes de continuar. '
              'Você poderá editá-los na próxima tela.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            _reviewRow(Icons.inventory_2, 'Nome', s.name),
            _reviewRow(Icons.qr_code, 'Código', s.barcode),
            _reviewRow(Icons.numbers, 'Lote', s.lote),
            _reviewRow(
                Icons.event_available, 'Fabricação', _fmt(s.manufacturingDate)),
            _reviewRow(Icons.event_busy, 'Validade', _fmt(s.expirationDate)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Revisar e editar'),
          ),
        ],
      ),
    );
  }

  Widget _reviewRow(IconData icon, String label, String? value) {
    final found = value != null && value.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon,
              size: 16,
              color: found ? Colors.green : Colors.grey.shade400),
          const SizedBox(width: 8),
          Text('$label: ',
              style: const TextStyle(
                  fontWeight: FontWeight.w500, fontSize: 13)),
          Expanded(
            child: Text(
              found ? value : '—',
              style: TextStyle(
                fontSize: 13,
                color: found ? Colors.black87 : Colors.grey,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String? _fmt(DateTime? d) {
    if (d == null) return null;
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
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
    final hasPreload = widget.initialSuggestion?.name != null;
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
            Text(
              hasPreload
                  ? 'Fotografe o verso da embalagem'
                  : 'Fotografe as partes do produto',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hasPreload
                  ? 'O produto "${widget.initialSuggestion!.name}" foi '
                      'encontrado. Tire foto do verso (validade, lote e '
                      'fabricação) para completar o cadastro.'
                  : 'Tire fotos da frente (nome), do verso (validade/lote) '
                      'e de qualquer código de barras. O app vai combinar '
                      'as informações.',
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
                    child: Icon(Icons.close,
                        color: Colors.white, size: 18),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
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
