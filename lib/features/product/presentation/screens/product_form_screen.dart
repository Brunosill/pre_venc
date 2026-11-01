import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/product.dart';
import '../../utils/product_parser.dart';
import '../providers/product_providers.dart';
import 'barcode_scanner_screen.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final ProductSuggestion? suggestion;
  final String? imagePath;
  final String? ocrText;
  final Product? existingProduct;

  const ProductFormScreen({
    super.key,
    this.suggestion,
    this.imagePath,
    this.ocrText,
    this.existingProduct,
  });

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();
  final _loteCtrl = TextEditingController();

  DateTime? _manufacturingDate;
  DateTime? _expirationDate;
  bool _saving = false;
  late ProductSource _source;

  @override
  void initState() {
    super.initState();

    if (widget.existingProduct != null) {
      final p = widget.existingProduct!;
      _nameCtrl.text = p.name;
      _barcodeCtrl.text = p.barcode ?? '';
      _loteCtrl.text = p.lote ?? '';
      _manufacturingDate = p.manufacturingDate;
      _expirationDate = p.expirationDate;
      _source = p.source;
    } else if (widget.suggestion != null) {
      final s = widget.suggestion!;
      _nameCtrl.text = s.name ?? '';
      _barcodeCtrl.text = s.barcode ?? '';
      _loteCtrl.text = s.lote ?? '';
      _manufacturingDate = s.manufacturingDate;
      _expirationDate = s.expirationDate;
      _source = s.source;
    } else {
      _source = ProductSource.manual;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _barcodeCtrl.dispose();
    _loteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isExpiration}) async {
    final now = DateTime.now();
    final initial = isExpiration
        ? (_expirationDate ?? now.add(const Duration(days: 180)))
        : (_manufacturingDate ?? now);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        if (isExpiration) {
          _expirationDate = picked;
        } else {
          _manufacturingDate = picked;
        }
      });
    }
  }

  Future<void> _scanBarcode() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (code != null && code.isNotEmpty) {
      setState(() => _barcodeCtrl.text = code);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      if (widget.existingProduct != null) {
        final updated = Product(
          id: widget.existingProduct!.id,
          name: _nameCtrl.text.trim(),
          barcode: _barcodeCtrl.text.trim().isEmpty
              ? null
              : _barcodeCtrl.text.trim(),
          lote: _loteCtrl.text.trim().isEmpty ? null : _loteCtrl.text.trim(),
          manufacturingDate: _manufacturingDate,
          expirationDate: _expirationDate,
          imagePath: widget.existingProduct!.imagePath,
          ocrText: widget.existingProduct!.ocrText,
          createdAt: widget.existingProduct!.createdAt,
          source: _source,
        );
        await ref.read(updateProductProvider)(updated);
      } else {
        final product = Product(
          id: const Uuid().v4(),
          name: _nameCtrl.text.trim(),
          barcode: _barcodeCtrl.text.trim().isEmpty
              ? null
              : _barcodeCtrl.text.trim(),
          lote: _loteCtrl.text.trim().isEmpty ? null : _loteCtrl.text.trim(),
          manufacturingDate: _manufacturingDate,
          expirationDate: _expirationDate,
          imagePath: widget.imagePath,
          ocrText: widget.ocrText,
          createdAt: DateTime.now(),
          source: _source,
        );
        await ref.read(addProductProvider)(product);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produto salvo!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Selecionar data';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Widget _buildSourceBadge() {
    final color = switch (_source) {
      ProductSource.ocr => Colors.blue,
      ProductSource.barcode => Colors.green,
      ProductSource.manual => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _source == ProductSource.ocr
            ? '📷 Origem: OCR'
            : _source == ProductSource.barcode
                ? '📊 Origem: Código de barras'
                : '✏️ Origem: Manual',
        style: TextStyle(color: color, fontSize: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingProduct == null
            ? 'Novo Produto'
            : 'Editar Produto'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(32),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildSourceBadge(),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nome do produto *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.inventory_2),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _barcodeCtrl,
              decoration: InputDecoration(
                labelText: 'Código de barras',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.qr_code),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.camera_alt),
                  tooltip: 'Escanear',
                  onPressed: _scanBarcode,
                ),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _loteCtrl,
              decoration: const InputDecoration(
                labelText: 'Lote',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.numbers),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 16),

            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: const BorderSide(color: Colors.grey),
              ),
              leading: const Icon(Icons.event_available),
              title: const Text('Data de fabricação'),
              subtitle: Text(_formatDate(_manufacturingDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _pickDate(isExpiration: false),
            ),
            const SizedBox(height: 16),

            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: const BorderSide(color: Colors.grey),
              ),
              leading: const Icon(Icons.event_busy),
              title: const Text('Data de validade'),
              subtitle: Text(_formatDate(_expirationDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _pickDate(isExpiration: true),
            ),
            const SizedBox(height: 32),

            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(_saving ? 'Salvando...' : 'Salvar produto'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
