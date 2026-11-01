import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../product/presentation/providers/product_providers.dart';
import '../providers/alerts_providers.dart';

/// Escuta mudanças nos produtos e reagenda notificações automaticamente.
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

    ref.listenManual(productsStreamProvider, (previous, next) async {
      final products = next.asData?.value;
      if (products == null) return;
      try {
        await ref.read(rescheduleAlertsProvider)();
      } catch (_) {
        // Silencioso: não quebra a UI por falha de agendamento
      }
    }, fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
