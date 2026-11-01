import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../alerts/presentation/screens/alert_settings_screen.dart';
import '../../domain/entities/product.dart';
import '../providers/product_providers.dart';
import '../widgets/expiring_week_banner.dart';
import 'product_form_screen.dart';

class ProductListScreen extends ConsumerWidget {
  const ProductListScreen({super.key});

  Color _statusColor(Product p) {
    if (p.isExpired) return Colors.red;
    if (p.isExpiringSoon) return Colors.orange;
    return Colors.green;
  }

  String _statusLabel(Product p) {
    final days = p.daysToExpire;
    if (days == null) return 'Sem validade';
    if (days < 0) return 'Vencido há ${-days} dia(s)';
    if (days == 0) return 'Vence hoje!';
    if (days <= 7) return 'Vence em $days dia(s)';
    return 'Vence em $days dia(s)';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsStreamProvider);

    return Scaffold(
      body: productsAsync.when(
        data: (products) {
          if (products.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inventory_2,
                        size: 96,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 16),
                    const Text(
                      'Nenhum produto cadastrado.\nUse o botão + para adicionar.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              const ExpiringWeekBanner(),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                  itemCount: products.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${products.length} produto(s)',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const AlertSettingsScreen(),
                                ),
                              ),
                              icon: const Icon(Icons.notifications_active,
                                  size: 18),
                              label: const Text('Alertas'),
                            ),
                          ],
                        ),
                      );
                    }

                    final p = products[index - 1];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              _statusColor(p).withValues(alpha: 0.15),
                          child: Icon(Icons.inventory_2,
                              color: _statusColor(p)),
                        ),
                        title: Text(p.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (p.barcode != null)
                              Text('Cód: ${p.barcode}',
                                  style: const TextStyle(fontSize: 12)),
                            if (p.lote != null)
                              Text('Lote: ${p.lote}',
                                  style: const TextStyle(fontSize: 12)),
                            Text(
                              _statusLabel(p),
                              style: TextStyle(
                                  color: _statusColor(p),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12),
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (action) async {
                            if (action == 'edit') {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProductFormScreen(
                                      existingProduct: p),
                                ),
                              );
                            } else if (action == 'delete') {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Excluir produto?'),
                                  content: Text('Remover "${p.name}"?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Cancelar'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, true),
                                      child: const Text('Excluir'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await ref.read(deleteProductProvider)(p.id);
                              }
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                                value: 'edit', child: Text('Editar')),
                            PopupMenuItem(
                                value: 'delete', child: Text('Excluir')),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ProductFormScreen(existingProduct: p),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
      ),
    );
  }
}