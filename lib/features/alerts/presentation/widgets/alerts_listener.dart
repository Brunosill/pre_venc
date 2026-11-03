import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../product/presentation/providers/inventory_providers.dart';
import '../providers/alerts_providers.dart';

/// Escuta mudanças nos itens do estoque e reagenda notificações automaticamente.
class AlertsListener extends ConsumerStatefulWidget {
  final Widget child;
  const AlertsListener({super.key, required this.child});

  @override
  ConsumerState<AlertsListener> createState() => _AlertsListenerState();
}

class _AlertsListenerState extends ConsumerState<AlertsListener> {
  @override
  void initState() {
    super.initState();

    ref.listenManual(inventoryItemsStreamProvider, (previous, next) async {
      final items = next.asData?.value;
      if (items == null) return;
      try {
        await ref.read(rescheduleAlertsProvider)();
      } catch (_) {
        // Silencioso: falha de agendamento não deve quebrar a UI
      }
    }, fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}