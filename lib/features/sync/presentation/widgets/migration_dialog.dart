import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../product/presentation/providers/inventory_providers.dart';
import '../providers/sync_providers.dart';

/// Mostra dialog "enviar X itens locais para a nuvem?" se:
/// - usuário logado
/// - existem itens com remoteId == null
/// - ainda não perguntou nesta sessão
class MigrationDialog extends ConsumerStatefulWidget {
  final Widget child;
  const MigrationDialog({super.key, required this.child});

  @override
  ConsumerState<MigrationDialog> createState() => _MigrationDialogState();
}

class _MigrationDialogState extends ConsumerState<MigrationDialog> {
  bool _asked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAsk());
  }

  Future<void> _maybeAsk() async {
    if (_asked || !mounted) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final items = ref.read(inventoryItemsStreamProvider).asData?.value ?? [];
    final pending = items.where((i) => i.remoteId == null).toList();
    if (pending.isEmpty) return;

    _asked = true;
    if (!mounted) return;

    final wants = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Enviar para a nuvem?'),
        content: Text(
          'Você tem ${pending.length} produto(s) cadastrado(s) apenas '
          'neste celular.\n\n'
          'Deseja enviá-los para sua conta para fazer backup e acessar '
          'em outros dispositivos?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Agora não'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );

    if (wants != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final count =
        await ref.read(syncStateProvider.notifier).migrate(user.id);

    messenger.showSnackBar(
      SnackBar(content: Text('$count produto(s) enviado(s) para a nuvem!')),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}