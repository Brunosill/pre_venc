import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/ocr_result.dart';
import '../providers/ocr_providers.dart';

class OcrResultScreen extends ConsumerStatefulWidget {
  final String imagePath;
  final OcrResult? preloadedResult;

  const OcrResultScreen({
    super.key,
    required this.imagePath,
    this.preloadedResult,
  });

  @override
  ConsumerState<OcrResultScreen> createState() => _OcrResultScreenState();
}

class _OcrResultScreenState extends ConsumerState<OcrResultScreen> {
  String? _extractedText;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.preloadedResult != null) {
      _extractedText = widget.preloadedResult!.extractedText;
    } else {
      _runOcr();
    }
  }

  Future<void> _runOcr() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final extractText = ref.read(extractTextProvider);
      final text = await extractText(widget.imagePath);

      final result = OcrResult(
        id: const Uuid().v4(),
        imagePath: widget.imagePath,
        extractedText: text,
        createdAt: DateTime.now(),
        textLength: text.length,
      );

      await ref.read(saveOcrResultProvider)(result);

      if (!mounted) return;
      setState(() {
        _extractedText = text;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _copyToClipboard() async {
    if (_extractedText == null) return;
    await Clipboard.setData(ClipboardData(text: _extractedText!));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Texto copiado!')),
    );
  }

  Future<void> _shareText() async {
  if (_extractedText == null) return;
  await SharePlus.instance.share(
    ShareParams(
      text: _extractedText!,
      subject: 'Texto extraído do Pre-Venc',
     ),
   );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resultado'),
        actions: [
          if (_extractedText != null)
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'Copiar texto',
              onPressed: _copyToClipboard,
            ),
          if (_extractedText != null)
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Compartilhar',
              onPressed: _shareText,
            ),
        ],
      ),
      body: _loading
          ? _buildLoading()
          : _error != null
              ? _buildError()
              : _buildResult(),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(widget.imagePath),
                height: 200,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('Extraindo texto...'),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _runOcr,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(widget.imagePath),
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              const Icon(Icons.text_fields, size: 20),
              const SizedBox(width: 8),
              Text(
                '${_extractedText!.length} caracteres',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(
              _extractedText!,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _copyToClipboard,
                  icon: const Icon(Icons.copy),
                  label: const Text('Copiar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _shareText,
                  icon: const Icon(Icons.share),
                  label: const Text('Compartilhar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}