import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/inventory_item.dart';
import '../providers/inventory_providers.dart';

class BatchScannerScreen extends ConsumerStatefulWidget {
  const BatchScannerScreen({super.key});

  @override
  ConsumerState<BatchScannerScreen> createState() => _BatchScannerScreenState();
}

class _BatchScannerScreenState extends ConsumerState<BatchScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  final Set<String> _scannedBarcodes = {};
  bool _isProcessing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    
    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue;
      if (code == null || code.isEmpty) continue;
      if (_scannedBarcodes.contains(code)) continue; // Evita duplicados na mesma sessão

      _isProcessing = true;
      _scannedBarcodes.add(code);

      // Cria um item rascunho
      final draft = InventoryItem(
        id: const Uuid().v4(),
        barcode: code,
        name: 'Produto Pendente ($code)',
        type: 0,
        isDraft: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await ref.read(addItemProvider)(draft);

      if (mounted) {
        // Feedback tátil e visual
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(milliseconds: 800),
            content: Text('✅ Adicionado: $code'),
          ),
        );
      }

      // Pequeno delay para o scanner não ler o mesmo código múltiplas vezes
      await Future.delayed(const Duration(seconds: 1));
      _isProcessing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modo Mercado'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // Overlay com instruções
          Positioned(
            top: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                children: [
                  Text(
                    'Aponte para o código de barras',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Escaneie quantos produtos quiser. Eles ficarão pendentes para completar depois.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
            ),
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.check),
            label: Text('Finalizar (${_scannedBarcodes.length} itens)'),
          ),
        ),
      ),
    );
  }
}