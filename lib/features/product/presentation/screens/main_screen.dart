import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../alerts/presentation/screens/alert_settings_screen.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/screens/profile_screen.dart';
import '../../../sync/presentation/providers/sync_providers.dart';
import '../../../sync/presentation/widgets/migration_dialog.dart';
import '../providers/filter_providers.dart';
import '../providers/inventory_providers.dart';
import '../widgets/expiring_week_banner.dart';
import '../widgets/inventory_item_card.dart';
import '../widgets/search_and_filters.dart';
import '../widgets/draft_banner.dart';
import 'entry_screen.dart';

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuth = ref.watch(isAuthenticatedProvider);
    final allItemsAsync = ref.watch(inventoryItemsStreamProvider);
    final filteredItems = ref.watch(filteredInventoryItemsProvider);
    final searchQuery = ref.watch(searchQueryProvider);
    final statusFilter = ref.watch(statusFilterProvider);
    final typeFilter = ref.watch(typeFilterProvider);

    // Detecta se algum filtro está ativo (para mostrar botão "Limpar")
    final hasActiveFilters = searchQuery.isNotEmpty ||
        statusFilter != StatusFilter.all ||
        typeFilter != null;

    return MigrationDialog(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Meu Estoque'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications_active_outlined),
              tooltip: 'Alertas de vencimento',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AlertSettingsScreen()),
              ),
            ),
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
        body: allItemsAsync.when(
          data: (allItems) {
            // Estado vazio absoluto (sem nenhum item)
            if (allItems.isEmpty) {
              return _EmptyStock();
            }

            return Column(
              children: [
                const DraftBanner(),
                const ExpiringWeekBanner(),
                const SearchAndFilters(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      Text(
                        '${filteredItems.length} produto(s)',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (hasActiveFilters) ...[
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () {
                            ref.read(searchQueryProvider.notifier).clear();
                            ref.read(statusFilterProvider.notifier).set(StatusFilter.all);
                            ref.read(typeFilterProvider.notifier).set(null);
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            child: Text(
                              'Limpar filtros',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      Icon(Icons.sort, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        'Vencimento',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: filteredItems.isEmpty
                      ? _NoResults(hasActiveFilters: hasActiveFilters)
                      : RefreshIndicator(
                    onRefresh: () async {
                      if (isAuth) {
                        await ref.read(syncStateProvider.notifier).sync();
                      }
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
                      itemCount: filteredItems.length,
                      itemBuilder: (context, index) {
                        return InventoryItemCard(
                            item: filteredItems[index]);
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
      ),
    );
  }
}

// ============ ESTADOS VAZIOS ============

class _EmptyStock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
}

class _NoResults extends StatelessWidget {
  final bool hasActiveFilters;
  const _NoResults({required this.hasActiveFilters});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              hasActiveFilters
                  ? 'Nenhum produto corresponde aos filtros'
                  : 'Nenhum produto',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Tente ajustar a busca ou limpar os filtros.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}