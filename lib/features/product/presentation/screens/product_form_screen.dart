
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../ocr/presentation/screens/multi_capture_screen.dart';
import '../../data/models/inventory_item.dart';
import '../providers/barcode_providers.dart';
import '../providers/inventory_providers.dart';
import 'barcode_scanner_screen.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final String? initialBarcode;
  final InventoryItem? existingItem;

  const ProductFormScreen({
    super.key,
    this.initialBarcode,
    this.existingItem,
  });

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();
  final _loteCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController(text: '1');

  int _type = 0; // 0=Alimento, 1=Medicamento, 2=Beleza
  DateTime? _manufacturingDate;
  DateTime? _expirationDate;
  String _unit = 'un';

  String? _ocrText1;
  String? _ocrText2;
  int _source = 2; // 0=OCR, 1=Barcode, 2=Manual

  bool _loadingInitial = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingItem != null) {
      _loadFromExisting(widget.existingItem!);
    } else if (widget.initialBarcode != null && widget.initialBarcode!.isNotEmpty) {
      _barcodeCtrl.text = widget.initialBarcode!;
      _fetchByBarcode(widget.initialBarcode!);
    }
  }

  void _loadFromExisting(InventoryItem item) {
    _nameCtrl.text = item.name;
    _barcodeCtrl.text = item.barcode ?? '';
    _loteCtrl.text = item.lote ?? '';
    _notesCtrl.text = item.notes ?? '';
    _quantityCtrl.text = item.quantity.toString();
    _type = item.type;
    _manufacturingDate = item.manufacturingDate;
    _expirationDate = item.expirationDate;
    _unit = item.unit ?? 'un';
    _source = item.source;
  }

  Future<void> _fetchByBarcode(String barcode) async {
    setState(() => _loadingInitial = true);
    try {
      final orchestrator = ref.read(barcodeOrchestratorProvider);
      final result = await orchestrator.lookupAuto(barcode);

      if (!mounted) return;
      if (result != null) {
        final name = result['name'] as String?;
        final brand = result['brand'] as String?;
        final category = result['category'] as String?;

        if (name != null && name.trim().isNotEmpty) {
          setState(() {
            _nameCtrl.text = brand != null && brand.isNotEmpty
                ? '$name ($brand)'
                : name.trim();
            if (category == 'food') _type = 0;
            if (category == 'medicine') _type = 1;
            if (category == 'beauty') _type = 2;
            _source = 1;
          });
        }
      }
    } catch (_) {
      // silencioso, usuário digita manualmente
    } finally {
      if (mounted) setState(() => _loadingInitial = false);
    }
  }

  Future<void> _pickDate({required bool isExpiration}) async {
    final initial = isExpiration
        ? (_expirationDate ?? DateTime.now().add(const Duration(days: 180)))
        : (_manufacturingDate ?? DateTime.now());

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
      setState(() {
        _barcodeCtrl.text = code;
        _source = 1;
      });
      await _fetchByBarcode(code);
    }
  }

  Future<void> _useOcr() async {
    final result = await Navigator.push<CaptureResult>(
      context,
      MaterialPageRoute(
        builder: (_) => MultiCaptureScreen(barcode: _barcodeCtrl.text),
      ),
    );
    if (result == null || !mounted) return;

    setState(() {
      if (result.suggestion.name != null && result.suggestion.name!.isNotEmpty) {
        _nameCtrl.text = result.suggestion.name!;
      }
      if (result.suggestion.lote != null) {
        _loteCtrl.text = result.suggestion.lote!;
      }
      if (result.suggestion.manufacturingDate != null) {
        _manufacturingDate = result.suggestion.manufacturingDate;
      }
      if (result.suggestion.expirationDate != null) {
        _expirationDate = result.suggestion.expirationDate;
      }

      _ocrText1 = result.ocrText1;
      _ocrText2 = result.ocrText2;
      _source = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dados extraídos. Revise antes de salvar.')),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final qty = double.tryParse(_quantityCtrl.text) ?? 1.0;
      final now = DateTime.now();

      final item = InventoryItem(
        id: widget.existingItem?.id ?? const Uuid().v4(),
        userId: widget.existingItem?.userId,
        barcode: _barcodeCtrl.text.trim().isEmpty ? null : _barcodeCtrl.text.trim(),
        type: _type,
        name: _nameCtrl.text.trim(),
        lote: _loteCtrl.text.trim().isEmpty ? null : _loteCtrl.text.trim(),
        manufacturingDate: _manufacturingDate,
        expirationDate: _expirationDate,
        quantity: qty,
        unit: _unit,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        source: _source,
        createdAt: widget.existingItem?.createdAt ?? now,
        updatedAt: now,
        deletedAt: null,
        isDraft: false,
      );

      if (widget.existingItem != null) {
        await ref.read(updateItemProvider)(item);
      } else {
        await ref.read(addItemProvider)(item);
      }

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.existingItem != null ? 'Item atualizado!' : 'Produto cadastrado!')),
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
    if (date == null) return 'Selecionar';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _barcodeCtrl.dispose();
    _loteCtrl.dispose();
    _notesCtrl.dispose();
    _quantityCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingItem == null ? 'Novo Produto' : 'Editar Produto'),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt),
            tooltip: 'Extrair do OCR',
            onPressed: _useOcr,
          ),
          if (_ocrText1 != null || _ocrText2 != null)
            IconButton(
              icon: const Icon(Icons.text_snippet),
              tooltip: 'Ver texto OCR',
              onPressed: () => _showOcrText(context),
            ),
        ],
      ),
      body: _loadingInitial
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Buscando produto...'),
                ],
              ),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Tipo
                  const Text('Tipo do produto', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildTypeChip('🍎 Alimento', 0),
                      _buildTypeChip('💊 Medicamento', 1),
                      _buildTypeChip('🧴 Beleza', 2),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Nome
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

                  // Código de barras
                  TextFormField(
                    controller: _barcodeCtrl,
                    decoration: InputDecoration(
                      labelText: 'Código de barras',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.qr_code),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.camera_alt),
                        onPressed: _scanBarcode,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),

                  // Lote
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

                  // Datas
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
                  const SizedBox(height: 16),

                  // Quantidade + Unidade
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _quantityCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Quantidade',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d\.]'))],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          initialValue: _unit,
                          decoration: const InputDecoration(
                            labelText: 'Unidade',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'un', child: Text('un')),
                            DropdownMenuItem(value: 'kg', child: Text('kg')),
                            DropdownMenuItem(value: 'g', child: Text('g')),
                            DropdownMenuItem(value: 'L', child: Text('L')),
                            DropdownMenuItem(value: 'ml', child: Text('ml')),
                            DropdownMenuItem(value: 'mg', child: Text('mg')),
                            DropdownMenuItem(value: 'cx', child: Text('cx')),
                          ],
                          onChanged: (v) => setState(() => _unit = v ?? 'un'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Notas
                  TextFormField(
                    controller: _notesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Observações',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.notes),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 32),

                  // Salvar
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

  Widget _buildTypeChip(String label, int value) {
    return ChoiceChip(
      label: Text(label),
      selected: _type == value,
      onSelected: (_) => setState(() => _type = value),
    );
  }

  void _showOcrText(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        expand: false,
        builder: (ctx, scrollCtrl) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Texto original do OCR',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  children: [
                    if (_ocrText1 != null) ...[
                      const Text('Foto 1 (frente):', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      SelectableText(_ocrText1!, style: const TextStyle(fontSize: 13)),
                      const SizedBox(height: 16),
                    ],
                    if (_ocrText2 != null) ...[
                      const Text('Foto 2 (verso):', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      SelectableText(_ocrText2!, style: const TextStyle(fontSize: 13)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
