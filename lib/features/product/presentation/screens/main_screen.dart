import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pre_venc/features/product/presentation/screens/product_form_screen.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/screens/profile_screen.dart';
import '../../../sync/presentation/widgets/migration_dialog.dart';
import '../../../sync/presentation/providers/sync_providers.dart';
import '../providers/inventory_providers.dart';
import '../widgets/expiring_week_banner.dart';
import '../widgets/inventory_item_card.dart';
import 'entry_screen.dart';

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuth = ref.watch(isAuthenticatedProvider);
    final itemsAsync = ref.watch(inventoryItemsStreamProvider);


    return MigrationDialog(
        child: Scaffold(
      appBar: AppBar(
        title: const Text('Meu Estoque'),
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
        ],
      ),
      body: itemsAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 96,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Seu estoque está vazio',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Adicione seu primeiro produto tocando no botão abaixo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              const DraftBanner(),
              const ExpiringWeekBanner(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    Text(
                      '${items.length} produto(s)',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.sort,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Vencimento',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async{
                    if (isAuth) {
                      await ref.read(syncStateProvider.notifier).sync();
                    }
                  },
                  child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    return InventoryItemCard(item: items[index]);
                  },
                ),
              ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Erro: $e', textAlign: TextAlign.center),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EntryScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Novo'),
      ),
    )
    );
  }
}
// Crie este widget no mesmo arquivo ou em widgets/draft_banner.dart
class DraftBanner extends ConsumerWidget {
  const DraftBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(inventoryItemsStreamProvider).asData?.value ?? [];
    final drafts = items.where((i) => i.isDraft).toList();

    if (drafts.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.pending_actions, color: Colors.amber),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Você tem ${drafts.length} produto(s) do mercado aguardando dados.',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () {
              // Abre o primeiro rascunho para completar
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProductFormScreen(existingItem: drafts.first),
                ),
              );
            },
            child: const Text('Completar'),
          ),
        ],
      ),
    );
  }
}
