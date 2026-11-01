import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../ocr/presentation/screens/home_screen.dart';
import '../../../ocr/presentation/screens/multi_capture_screen.dart';
import '../../data/services/barcode_lookup_service.dart';
import '../../utils/product_parser.dart';
import '../widgets/add_product_choice_sheet.dart';
import 'barcode_scanner_screen.dart';
import 'product_form_screen.dart';
import 'product_list_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final _lookup = BarcodeLookupService();

  Future<void> _onAddProduct() async {
    final method = await AddProductChoiceSheet.show(context);
    if (method == null || !mounted) return;

    switch (method) {
      case AddProductMethod.camera:
        await _openCaptureWithCameraPermission();
        break;
      case AddProductMethod.gallery:
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const MultiCaptureScreen(useCameraFirst: false),
          ),
        );
        break;
      case AddProductMethod.barcode:
        await _flowBarcode();
        break;
      case AddProductMethod.manual:
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProductFormScreen()),
        );
        break;
    }
  }

  Future<void> _openCaptureWithCameraPermission() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permissão de câmera necessária.')),
      );
      return;
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MultiCaptureScreen(useCameraFirst: true),
      ),
    );
  }

  Future<void> _flowBarcode() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (code == null || code.isEmpty || !mounted) return;

    // Mostra loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final suggestion = await _lookup.lookup(code);

    if (!mounted) return;
    Navigator.pop(context); // fecha loading

    if (suggestion != null && suggestion.name != null) {
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductFormScreen(suggestion: suggestion),
        ),
      );
    } else {
      if (!mounted) return;
      _showNotFoundDialog(code);
    }
  }

  void _showNotFoundDialog(String code) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Produto não encontrado'),
        content: Text(
          'O código $code não está na base Open Food Facts.\n\n'
          'Você pode fotografar a embalagem para o OCR tentar extrair '
          'as informações, ou digitar manualmente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProductFormScreen(
                    suggestion: ProductSuggestion(barcode: code),
                  ),
                ),
              );
            },
            child: const Text('Digitar manualmente'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _openCaptureWithCameraPermission();
            },
            child: const Text('Fotografar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Produtos'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Histórico de OCR',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            ),
          ),
        ],
      ),
      body: const ProductListScreen(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _onAddProduct,
        icon: const Icon(Icons.add),
        label: const Text('Produto'),
      ),
    );
  }
}
