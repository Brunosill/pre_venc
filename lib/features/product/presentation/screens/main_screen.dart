import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/screens/profile_screen.dart';
import '../../data/models/inventory_item.dart';
import '../providers/inventory_providers.dart';
import 'entry_screen.dart';

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuth = ref.watch(isAuthenticatedProvider);
    final itemsAsync = ref.watch(inventoryItemsStreamProvider);

    return Scaffold(
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
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Seu estoque está vazio.'),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.inventory_2),
                  title: Text(item.name),
                  subtitle: Text(
                    item.expirationDate != null
                        ? 'Vence: ${item.expirationDate!.day}/${item.expirationDate!.month}/${item.expirationDate!.year}'
                        : 'Sem validade',
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EntryScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Novo'),
      ),
    );
  }
}
