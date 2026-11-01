import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/screens/profile_screen.dart';
import '../../../ocr/presentation/screens/home_screen.dart';
import '../../../ocr/presentation/screens/multi_capture_screen.dart';
import '../../domain/entities/product.dart';
import '../../utils/product_parser.dart';
import '../providers/barcode_providers.dart';
import '../widgets/add_product_choice_sheet.dart';
import 'barcode_scanner_screen.dart';
import 'product_form_screen.dart';
import 'product_list_screen.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
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

  Future<void> _openCaptureWithCameraPermission({
    ProductSuggestion? initialSuggestion,
  }) async {
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
        builder: (_) => MultiCaptureScreen(
          useCameraFirst: true,
          initialSuggestion: initialSuggestion,
        ),
      ),
    );
  }

  Future<void> _flowBarcode() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (code == null || code.isEmpty || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    Map<String, dynamic>? result;
    try {
      result = await ref.read(barcodeOrchestratorProvider).lookupAuto(code);
    } catch (_) {
      result = null;
    }

    if (!mounted) return;
    Navigator.pop(context);

    final name = result?['name'] as String?;
    final brand = result?['brand'] as String?;
    final categoryName = result?['category'] as String?;

    if (result != null && name != null && name.trim().isNotEmpty) {
      final displayName = _composeDisplayName(name.trim(), brand);

      final wantsPhoto = await _askToCaptureForDetails(displayName);
      if (wantsPhoto == null || !mounted) return;

      final suggestion = ProductSuggestion(
        name: name.trim(),
        barcode: code,
        source: ProductSource.barcode,
      );

      if (wantsPhoto) {
        await _openCaptureWithCameraPermission(initialSuggestion: suggestion);
      } else {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductFormScreen(suggestion: suggestion),
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    _showNotFoundDialog(code, categoryName);
  }

  String _composeDisplayName(String name, String? brand) {
    if (brand == null || brand.trim().isEmpty) return name;
    return '$name ($brand)';
  }

  Future<bool?> _askToCaptureForDetails(String productName) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Produto encontrado!'),
          ],
        ),
        content: Text(
          'Encontramos "$productName" nas bases públicas.\n\n'
              'Ainda faltam os dados de validade, lote e fabricação. '
              'Deseja fotografar a embalagem para extrair essas informações '
              'automaticamente?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Preencher manualmente'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.camera_alt),
            label: const Text('Fotografar'),
          ),
        ],
      ),
    );
  }

  void _showNotFoundDialog(String code, String? detectedCategory) {
    final sourceHint = detectedCategory != null
        ? 'Não encontramos o código $code nas bases consultadas.'
        : 'O código $code não está em nenhuma base pública.';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Produto não encontrado'),
        content: Text(
          '$sourceHint\n\n'
              'Você pode fotografar a embalagem para o OCR extrair as '
              'informações, ou digitar manualmente.',
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
              _openCaptureWithCameraPermission(
                initialSuggestion: ProductSuggestion(barcode: code),
              );
            },
            child: const Text('Fotografar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAuth = ref.watch(isAuthenticatedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Produtos'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              isAuth ? Icons.account_circle : Icons.account_circle_outlined,
            ),
            tooltip: isAuth ? 'Meu perfil' : 'Entrar',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
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