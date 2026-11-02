import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/services/sync_service.dart';

final syncServiceProvider = Provider<SyncService?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return null;
  return SyncService(client);
});

final syncStateProvider =
NotifierProvider<SyncNotifier, AsyncValue<SyncResult?>>(SyncNotifier.new);

class SyncNotifier extends Notifier<AsyncValue<SyncResult?>> {
  @override
  AsyncValue<SyncResult?> build() {
    return const AsyncValue.data(null);
  }

  Future<void> sync() async {
    final service = ref.read(syncServiceProvider);
    if (service == null) {
      state = const AsyncValue.data(null);
      return;
    }
    state = const AsyncValue.loading();
    try {
      final result = await service.syncAll();
      state = AsyncValue.data(result);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<int> migrate(String userId) async {
    final service = ref.read(syncServiceProvider);
    if (service == null) return 0;
    return service.migrateLocalItems(userId);
  }

  DateTime? get lastSync => ref.read(syncServiceProvider)?.lastSync;
}