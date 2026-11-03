import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/inventory_providers.dart';
import '../screens/product_form_screen.dart';

class DraftBanner extends ConsumerWidget {
  const DraftBanner({super.key});  // ← construtor const

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items =
        ref.watch(inventoryItemsStreamProvider).asData?.value ?? [];
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
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    ProductFormScreen(existingItem: drafts.first),
              ),
            ),
            child: const Text('Completar'),
          ),
        ],
      ),
    );
  }
}