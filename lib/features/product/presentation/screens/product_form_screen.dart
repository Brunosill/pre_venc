
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/hive_boxes.dart';
import '../../utils/inventory_id.dart';
import '../../../ocr/presentation/screens/multi_capture_screen.dart';
import '../../data/models/inventory_item.dart';
import '../../domain/entities/product.dart';
import '../../utils/product_parser.dart';
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
    if (barcode.trim().isEmpty) return;

    // ============================================================
    // 1. BUSCA NO ESTOQUE LOCAL (por barcode, independente do lote)
    // ============================================================
    final localMatches = HiveBoxes.inventoryItemBox.values
        .where((i) => i.deletedAt == null && i.barcode == barcode)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    if (localMatches.isNotEmpty && mounted) {
      final reference = localMatches.first;
      final apiName = reference.name;
      final currentName = _nameCtrl.text.trim();

      bool shouldApply = true;

      // Se o usuário já digitou um nome diferente, perguntar
      if (currentName.isNotEmpty &&
          currentName.toLowerCase() != apiName.toLowerCase()) {
        final choice = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Produto já cadastrado'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Encontramos ${localMatches.length} entrada(s) com este '
                      'código no seu estoque.',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Nome cadastrado: $apiName',
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                      if (reference.lote != null)
                        Text('Lote mais recente: ${reference.lote}',
                            style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Você digitou: "$currentName"\n\n'
                      'Deseja usar o nome já cadastrado?',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Manter o meu'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Usar o cadastrado'),
              ),
            ],
          ),
        );
        shouldApply = choice ?? false;
      }

      if (shouldApply && mounted) {
        setState(() {
          _nameCtrl.text = apiName;
          _type = reference.type;
          // Herda unidade e categoria para facilitar
          if (reference.unit != null) _unit = reference.unit!;
          // Marca origem como "herdada do estoque" (source 1 = barcode)
          _source = 1;
        });
      }
      return; // Não consulta API — já tem dados locais
    }

    // ============================================================
    // 2. NÃO EXISTE LOCALMENTE → CONSULTA API
    // ============================================================
    setState(() => _loadingInitial = true);
    try {
      final orchestrator = ref.read(barcodeOrchestratorProvider);
      final result = await orchestrator.lookupAuto(barcode);

      if (!mounted || result == null) return;

      final name = result['name'] as String?;
      final brand = result['brand'] as String?;
      final category = result['category'] as String?;
      if (name == null || name.trim().isEmpty) return;

      final apiName = brand != null && brand.isNotEmpty
          ? '${name.trim()} ($brand)'
          : name.trim();
      final currentName = _nameCtrl.text.trim();

      bool shouldApply = true;

      // Se já digitou um nome diferente, perguntar
      if (currentName.isNotEmpty &&
          currentName.toLowerCase() != apiName.toLowerCase()) {
        final choice = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Substituir dados?'),
            content: Text(
              'Você digitou:\n"$currentName"\n\n'
                  'A API retornou:\n"$apiName"\n\n'
                  'Deseja substituir?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Manter o meu'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Usar da API'),
              ),
            ],
          ),
        );
        shouldApply = choice ?? false;
      }

      if (shouldApply && mounted) {
        setState(() {
          _nameCtrl.text = apiName;
          if (category == 'food') _type = 0;
          if (category == 'medicine') _type = 1;
          if (category == 'beauty') _type = 2;
          _source = 1;
        });
      }
    } catch (_) {
      // silencioso
    } finally {
      if (mounted) setState(() => _loadingInitial = false);
    }
  }

  Future<void> _reportProblem() async {
    if (widget.existingItem == null) return;

    // Captura context-bound objects ANTES de qualquer await
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final feedbackService = ref.read(feedbackServiceProvider);

    if (feedbackService == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Feedback indisponível: Supabase não configurado.'),
        ),
      );
      return;
    }

    // 1. Pergunta o que estava errado (primeiro await)
    final whatWasWrong = await showDialog<List<String>>(
      context: context,
      builder: (_) => const _ReportProblemDialog(),
    );
    if (whatWasWrong == null || whatWasWrong.isEmpty) return;
    if (!mounted) return;

    // 2. Mostra loading (sem await — só dispara e segue)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final originalSuggestion = ProductSuggestion(
        name: widget.existingItem!.name,
        barcode: widget.existingItem!.barcode,
        lote: widget.existingItem!.lote,
        manufacturingDate: widget.existingItem!.manufacturingDate,
        expirationDate: widget.existingItem!.expirationDate,
        source: ProductSource.ocr,
      );

      // Usa os valores ATUAIS do form (que o usuário pode ter corrigido)
      final corrected = InventoryItem(
        id: widget.existingItem!.id,
        userId: widget.existingItem!.userId,
        barcode: _barcodeCtrl.text.trim().isEmpty
            ? null
            : _barcodeCtrl.text.trim(),
        type: _type,
        name: _nameCtrl.text.trim(),
        lote: _loteCtrl.text.trim().isEmpty ? null : _loteCtrl.text.trim().toUpperCase(),

        manufacturingDate: _manufacturingDate,
        expirationDate: _expirationDate,
        quantity: widget.existingItem!.quantity,
        unit: widget.existingItem!.unit,
        notes: widget.existingItem!.notes,
        source: widget.existingItem!.source,
        createdAt: widget.existingItem!.createdAt,
        updatedAt: DateTime.now(),
      );

      await feedbackService.submit(
        correctedItem: corrected,
        originalSuggestion: originalSuggestion,
        whatWasWrong: whatWasWrong,
      );

      if (!mounted) return;
      navigator.pop(); // fecha loading
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Obrigado! Vamos analisar e melhorar o app.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      navigator.pop(); // fecha loading
      messenger.showSnackBar(
        SnackBar(content: Text('Erro ao enviar feedback: $e')),
      );
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

    final s = result.suggestion;

    final hasData = _nameCtrl.text.trim().isNotEmpty ||
        _loteCtrl.text.trim().isNotEmpty ||
        _manufacturingDate != null ||
        _expirationDate != null ||
        _barcodeCtrl.text.trim().isNotEmpty;

    String mergeMode = 'fill_empty'; // 'fill_empty' | 'overwrite' | 'keep'

    if (hasData) {
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Como combinar?'),
          content: const Text(
            'Você já preencheu alguns campos. Como deseja combinar com o OCR?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'keep'),
              child: const Text('Manter os meus'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'fill_empty'),
              child: const Text('Só preencher vazios'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'overwrite'),
              child: const Text('Substituir tudo'),
            ),
          ],
        ),
      );
      if (choice == null) return;
      mergeMode = choice;
    }

    int filled = 0;
    setState(() {
      void apply(String? incoming, String current, void Function(String) set) {
        if (incoming == null || incoming.isEmpty) return;
        if (mergeMode == 'keep') return;
        if (mergeMode == 'overwrite' || current.trim().isEmpty) {
          set(incoming);
          if (current != incoming) filled++;
        }
      }

      void applyDate(DateTime? incoming, DateTime? current,
          void Function(DateTime) set) {
        if (incoming == null) return;
        if (mergeMode == 'keep') return;
        if (mergeMode == 'overwrite' || current == null) {
          set(incoming);
          if (current != incoming) filled++;
        }
      }

      apply(s.name, _nameCtrl.text, (v) => _nameCtrl.text = v);
      apply(s.lote, _loteCtrl.text, (v) => _loteCtrl.text = v);
      apply(s.barcode, _barcodeCtrl.text, (v) => _barcodeCtrl.text = v);
      applyDate(s.manufacturingDate, _manufacturingDate,
              (v) => _manufacturingDate = v);
      applyDate(s.expirationDate, _expirationDate, (v) => _expirationDate = v);

      if (result.ocrText1 != null) _ocrText1 = result.ocrText1;
      if (result.ocrText2 != null) _ocrText2 = result.ocrText2;

      if (filled > 0) _source = 0;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(filled == 0
            ? 'Nada alterado.'
            : '$filled campo(s) atualizado(s) pelo OCR.'),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final qty = double.tryParse(_quantityCtrl.text) ?? 1.0;
      final now = DateTime.now();

      final item = InventoryItem(
        id: widget.existingItem?.id ?? InventoryId.generate(
          barcode: _barcodeCtrl.text.trim(),
          lote: _loteCtrl.text.trim(),
        ),
        userId: widget.existingItem?.userId,
        barcode: _barcodeCtrl.text.trim().isEmpty
            ? null
            : _barcodeCtrl.text.trim(),
        type: _type,
        name: _nameCtrl.text.trim(),
        lote: _loteCtrl.text.trim().isEmpty
            ? null
            : _loteCtrl.text.trim().toUpperCase(), // ← normalizado
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

      // ============ VERIFICA CONFLITO ANTES DE SALVAR ============
      // Se já existe item com mesmo ID (barcode_lote), pergunta ao usuário.
      if (widget.existingItem == null) {
        final existing = HiveBoxes.inventoryItemBox.get(item.id);
        if (existing != null && existing.deletedAt == null) {
          if (!mounted) return;

          final choice = await showDialog<String>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Produto já existe'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Já existe uma entrada com este código e lote:'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Nome: ${existing.name}',
                            style: const TextStyle(fontWeight: FontWeight.w500)),
                        Text('Lote: ${existing.lote ?? "sem lote"}'),
                        Text(
                            'Quantidade atual: ${existing.quantity.toStringAsFixed(0)} ${existing.unit ?? "un"}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'O que deseja fazer com a entrada de '
                        '${item.quantity.toStringAsFixed(0)} ${item.unit ?? "un"}?',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'sum_only'),
                  child: const Text('Só somar quantidade'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, 'update'),
                  child: const Text('Atualizar dados'),
                ),
              ],
            ),
          );

          if (choice == null) {
            // Usuário cancelou
            if (mounted) setState(() => _saving = false);
            return;
          }

          if (choice == 'update') {
            // Sobrescreve os dados existentes com o que o usuário digitou
            final updated = InventoryItem(
              id: existing.id,
              userId: existing.userId,
              barcode: item.barcode,
              type: item.type,
              name: item.name,           // ← nome novo prevalece
              lote: item.lote,
              manufacturingDate: item.manufacturingDate,
              expirationDate: item.expirationDate,
              quantity: existing.quantity + item.quantity, // soma quantidade
              unit: item.unit,
              notes: item.notes,
              source: item.source,
              createdAt: existing.createdAt,
              updatedAt: DateTime.now(),
              deletedAt: null,
              isDraft: false,
              remoteId: existing.remoteId,
              syncStatus: 0,
            );
            await ref.read(updateItemProvider)(updated);

            if (!mounted) return;
            navigator.pop();
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  'Dados atualizados e quantidade somada '
                      '(${updated.quantity.toStringAsFixed(0)} ${updated.unit ?? "un"}).',
                ),
              ),
            );
            return;
          }

          // choice == 'sum_only' — apenas incrementa quantidade
          existing.quantity += item.quantity;
          existing.updatedAt = DateTime.now();
          existing.syncStatus = 0;
          await existing.save();

          if (!mounted) return;
          navigator.pop();
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                'Quantidade somada (total: '
                    '${existing.quantity.toStringAsFixed(0)} ${existing.unit ?? "un"}).',
              ),
            ),
          );
          return;
        }
      }

      // ============ SALVAMENTO NORMAL ============
      late final InventoryItem result;
      if (widget.existingItem != null) {
        result = await ref.read(updateItemProvider)(item);
      } else {
        result = await ref.read(addItemProvider)(item);
      }
      if (!mounted) return;
      navigator.pop();

      // Feedback contextual
      if (result.id != item.id) {
        // Houve merge (o resultado é um item diferente do que tentamos salvar)
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Quantidade adicionada a "${result.name}" '
                  '(total: ${result.quantity.toStringAsFixed(0)}).',
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      } else if (widget.existingItem != null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Item atualizado!')),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('Produto cadastrado!')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
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

          if (widget.existingItem != null)
            IconButton(
              icon: const Icon(Icons.report_problem_outlined),
              tooltip: 'Reportar problema',
              onPressed: _reportProblem,
            ),

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

class _ReportProblemDialog extends StatefulWidget {
  const _ReportProblemDialog();

  @override
  State<_ReportProblemDialog> createState() => _ReportProblemDialogState();
}

class _ReportProblemDialogState extends State<_ReportProblemDialog> {
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.report_problem, color: Colors.orange),
          SizedBox(width: 8),
          Text('Reportar problema'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'O que estava errado nos dados extraídos?',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 8),
          _buildCheckbox('Nome', 'name'),
          _buildCheckbox('Lote', 'lote'),
          _buildCheckbox('Datas', 'date'),
          const SizedBox(height: 12),
          const Text(
            'Vamos enviar o texto OCR e as fotos anonimizadas '
                '(sem GPS ou dados pessoais) para melhorar o app.',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.pop(context, _selected.toList()),
          child: const Text('Enviar'),
        ),
      ],
    );
  }

  Widget _buildCheckbox(String label, String value) {
    return CheckboxListTile(
      title: Text(label),
      value: _selected.contains(value),
      onChanged: (checked) {
        setState(() {
          if (checked == true) {
            _selected.add(value);
          } else {
            _selected.remove(value);
          }
        });
      },
      contentPadding: EdgeInsets.zero,
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
    );
  }
}