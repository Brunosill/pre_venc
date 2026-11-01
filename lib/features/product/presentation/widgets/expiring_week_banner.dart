import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../alerts/presentation/providers/alerts_providers.dart';

class ExpiringWeekBanner extends ConsumerWidget {
  const ExpiringWeekBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expiring = ref.watch(expiringThisWeekProvider);
    if (expiring.isEmpty) return const SizedBox.shrink();

    final expired = expiring.where((p) => p.isExpired).length;
    final expiringSoon = expiring.length - expired;

    final String message;
    if (expired > 0 && expiringSoon > 0) {
      message = '$expired vencido(s) e $expiringSoon vencendo esta semana';
    } else if (expired > 0) {
      message = '$expired produto(s) já vencido(s)!';
    } else {
      message = '$expiringSoon produto(s) vencem esta semana';
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: expired > 0 ? Colors.red.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: expired > 0 ? Colors.red.shade300 : Colors.orange.shade300,
        ),
      ),
      child: Row(
        children: [
          Icon(
            expired > 0 ? Icons.error : Icons.warning_amber_rounded,
            color: expired > 0 ? Colors.red : Colors.orange.shade800,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: expired > 0 ? Colors.red.shade900 : Colors.orange.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}