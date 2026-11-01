import 'package:flutter/material.dart';

import '../../../ocr/presentation/screens/home_screen.dart';
import 'product_form_screen.dart';
import 'product_list_screen.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  Future<void> _openNewProduct(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProductFormScreen()),
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
        onPressed: () => _openNewProduct(context),
        icon: const Icon(Icons.add),
        label: const Text('Produto'),
      ),
    );
  }
}
