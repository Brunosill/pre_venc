import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'barcode_scanner_screen.dart';
import 'product_form_screen.dart';
import 'batch_scanner_screen.dart';

class EntryScreen extends StatefulWidget {
  const EntryScreen({super.key});

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  final _barcodeCtrl = TextEditingController();

  @override
  void dispose() {
    _barcodeCtrl.dispose();
    super.dispose();
  }

  void _proceedWithBarcode(String barcode) {
    if (barcode.trim().isEmpty) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ProductFormScreen(initialBarcode: barcode.trim()),
      ),
    );
  }

  Future<void> _scanBarcode() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (code != null && code.isNotEmpty && mounted) {
      _proceedWithBarcode(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Novo Produto'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.qr_code_scanner,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            const Text(
              'Identifique o produto',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Escaneie o código de barras ou digite manualmente para buscar os dados.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 40),
            
            // Campo de texto para o código
            TextField(
              controller: _barcodeCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Código de barras',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.numbers),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () => _proceedWithBarcode(_barcodeCtrl.text),
                ),
              ),
              onSubmitted: _proceedWithBarcode,
            ),
            const SizedBox(height: 24),

            // Botão de escanear
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: _scanBarcode,
                icon: const Icon(Icons.camera_alt),
                label: const Text(
                  'Escanear com a câmera',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const BatchScannerScreen()),
                  );
                },
                icon: const Icon(Icons.shopping_cart),
                label: const Text('Modo Mercado (Vários Produtos)'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}