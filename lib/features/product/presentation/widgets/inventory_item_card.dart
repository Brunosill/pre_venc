import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/inventory_item.dart';
import '../providers/inventory_providers.dart';
import '../screens/product_form_screen.dart';

class InventoryItemCard extends ConsumerWidget {
  final InventoryItem item;
  const InventoryItemCard({super.key, required this.item});

  // Cor baseada na urgência da validade
  Color _statusColor() {
    if (item.expirationDate == null) return Colors.grey;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final exp = item.expirationDate!;
    final days = DateTime(exp.year, exp.month, exp.day).difference(today).inDays;

    if (days < 0) return Colors.red;
    if (days <= 7) return Colors.orange;
    if (days <= 30) return Colors.amber.shade700;
    return Colors.green;
  }

  String _statusLabel() {
    if (item.expirationDate == null) return 'Sem validade';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final exp = item.expirationDate!;
    final days = DateTime(exp.year, exp.month, exp.day).difference(today).inDays;

    if (days < 0) return 'Vencido há ${-days} dia(s)';
    if (days == 0) return 'Vence hoje!';
    if (days == 1) return 'Vence amanhã';
    return 'Vence em $days dia(s)';
  }

  IconData _typeIcon() {
    switch (item.type) {
      case 1:
        return Icons.medication;
      case 2:
        return Icons.spa;
      default:
        return Icons.restaurant;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir produto?'),
        content: Text('Remover "${item.name}" do estoque?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(deleteItemProvider)(item.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _statusColor();
    final qtyLabel = item.quantity == item.quantity.roundToDouble()
        ? item.quantity.toInt().toString()
        : item.quantity.toString();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductFormScreen(existingItem: item),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Ícone por tipo
              CircleAvatar(
                radius: 24,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(_typeIcon(), color: color, size: 24),
              ),
              const SizedBox(width: 12),

              // Conteúdo
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (item.lote != null) ...[
                          Icon(Icons.numbers, size: 12, color: Colors.grey.shade600),
                          const SizedBox(width: 2),
                          Text(
                            item.lote!,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Text(
                          '$qtyLabel ${item.unit ?? 'un'}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.event, size: 12, color: color),
                        const SizedBox(width: 2),
                        Text(
                          _statusLabel(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                        if (item.expirationDate != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            '(${_formatDate(item.expirationDate)})',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Menu de ações
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) async {
                  if (value == 'edit') {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductFormScreen(existingItem: item),
                      ),
                    );
                  } else if (value == 'delete') {
                    await _confirmDelete(context, ref);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 18),
                        SizedBox(width: 8),
                        Text('Editar'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Excluir', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}