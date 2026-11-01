import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/product.dart';
import '../../utils/product_parser.dart';
import '../providers/barcode_providers.dart';
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

  bool _nameAuto = false;
  bool _barcodeAuto = false;
  bool _loteAuto = false;
  bool _fabAuto = false;
  bool _expAuto = false;

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
      _nameAuto = s.name != null;
      _barcodeAuto = s.barcode != null;
      _loteAuto = s.lote != null;
      _fabAuto = s.manufacturingDate != null;
      _expAuto = s.expirationDate != null;
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
          _expAuto = false;
        } else {
          _manufacturingDate = picked;
          _fabAuto = false;
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
      setState(() {
        _barcodeCtrl.text = code;
        _barcodeAuto = false;
      });
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

        // Oferece contribuição ao catálogo (só produto novo)
        await _offerCatalogContribution(product);
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

  Future<void> _offerCatalogContribution(Product product) async {
    if (product.barcode == null || product.barcode!.isEmpty) return;
    if (widget.existingProduct != null) return;

    final contributionService =
    ref.read(catalogContributionServiceProvider);
    if (contributionService == null) return;

    final alreadyIn =
    await contributionService.isInCatalog(product.barcode!);
    if (alreadyIn) return;

    if (!mounted) return;

    final wants = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Contribuir ao catálogo?'),
        content: Text(
          'O código ${product.barcode} ainda não está no catálogo público. '
              'Deseja compartilhar o nome "${product.name}" para ajudar outros '
              'usuários?\n\n'
              'Nenhum dado pessoal (validade, lote) será compartilhado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Não'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Contribuir'),
          ),
        ],
      ),
    );

    if (wants == true) {
      final ok = await contributionService.contribute(product);
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Obrigado! Produto adicionado ao catálogo.'),
          ),
        );
      }
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
    final label = switch (_source) {
      ProductSource.ocr => '📷 Extraído por OCR',
      ProductSource.barcode => '📊 Vindo do código de barras',
      ProductSource.manual => '✏️ Cadastro manual',
    };
    return Chip(
      avatar: const Icon(Icons.info_outline, size: 16),
      label: Text(label, style: TextStyle(color: color, fontSize: 12)),
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide(color: color.withValues(alpha: 0.4)),
    );
  }

  Widget _autoBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'auto',
        style: TextStyle(
          color: Colors.green,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildReviewBanner() {
    if (widget.existingProduct != null) return const SizedBox.shrink();

    final hasAuto =
        _nameAuto || _barcodeAuto || _loteAuto || _fabAuto || _expAuto;
    if (!hasAuto) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Dados extraídos automaticamente. Revise e edite '
                  'antes de salvar.',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  void _showOcrText() {
    if (widget.ocrText == null || widget.ocrText!.isEmpty) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollCtrl) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.text_snippet),
                  const SizedBox(width: 8),
                  const Text(
                    'Texto original do OCR',
                    style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollCtrl,
                  child: SelectableText(
                    widget.ocrText!,
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasOcrText =
        widget.ocrText != null && widget.ocrText!.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingProduct == null
            ? 'Novo Produto'
            : 'Editar Produto'),
        actions: [
          if (hasOcrText)
            IconButton(
              icon: const Icon(Icons.text_snippet),
              tooltip: 'Ver texto OCR',
              onPressed: _showOcrText,
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(36),
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
            _buildReviewBanner(),
            TextFormField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: 'Nome do produto *',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.inventory_2),
                suffixIcon: _nameAuto ? _autoBadge() : null,
              ),
              onChanged: (_) => setState(() => _nameAuto = false),
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
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_barcodeAuto) _autoBadge(),
                    IconButton(
                      icon: const Icon(Icons.camera_alt),
                      tooltip: 'Escanear',
                      onPressed: _scanBarcode,
                    ),
                  ],
                ),
              ),
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() => _barcodeAuto = false),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _loteCtrl,
              decoration: InputDecoration(
                labelText: 'Lote',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.numbers),
                suffixIcon: _loteAuto ? _autoBadge() : null,
              ),
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() => _loteAuto = false),
            ),
            const SizedBox(height: 16),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: BorderSide(
                  color: _fabAuto ? Colors.green : Colors.grey,
                  width: _fabAuto ? 2 : 1,
                ),
              ),
              leading: const Icon(Icons.event_available),
              title: Row(
                children: [
                  const Text('Data de fabricação'),
                  if (_fabAuto) ...[
                    const SizedBox(width: 8),
                    _autoBadge(),
                  ],
                ],
              ),
              subtitle: Text(_formatDate(_manufacturingDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _pickDate(isExpiration: false),
            ),
            const SizedBox(height: 16),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: BorderSide(
                  color: _expAuto ? Colors.green : Colors.grey,
                  width: _expAuto ? 2 : 1,
                ),
              ),
              leading: const Icon(Icons.event_busy),
              title: Row(
                children: [
                  const Text('Data de validade'),
                  if (_expAuto) ...[
                    const SizedBox(width: 8),
                    _autoBadge(),
                  ],
                ],
              ),
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