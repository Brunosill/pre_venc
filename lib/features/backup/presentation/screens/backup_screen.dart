import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/services/backup_service.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final _service = BackupService();
  bool _loading = false;

  Future<void> _export() async {
    setState(() => _loading = true);
    try {
      final file = await _service.exportBackup();
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Backup Pre-Venc',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _import() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    // file_picker 13.x retorna List<PlatformFile> diretamente
    final result = await FilePicker.pickFiles();
    if (result.isEmpty) return;

    final path = result.first.path;
    if (path == null) return;

    final file = File(path);
    if (!file.path.endsWith('.pvbackup')) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Selecione um arquivo .pvbackup válido.')),
      );
      return;
    }

    if (!mounted) return;
    final strategy = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurar Backup'),
        content: const Text('Deseja mesclar com os dados atuais ou substituir tudo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Substituir', style: TextStyle(color: Colors.red)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Mesclar'),
          ),
        ],
      ),
    );

    if (strategy == null) return;

    setState(() => _loading = true);
    try {
      await _service.importBackup(file, merge: strategy);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Backup restaurado com sucesso!')),
      );
      navigator.pop();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Erro: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup e Restauração')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.upload_file, color: Colors.blue),
              title: const Text('Exportar Backup'),
              subtitle: const Text('Salve seus dados e fotos em um arquivo seguro.'),
              onTap: _export,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.download, color: Colors.green),
              title: const Text('Importar Backup'),
              subtitle: const Text('Restaure seus dados a partir de um arquivo .pvbackup'),
              onTap: _import,
            ),
          ),
        ],
      ),
    );
  }
}