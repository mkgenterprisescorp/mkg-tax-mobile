import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/laravel_api_client.dart';
import 'sync_coordinator.dart';
import 'sync_cursor_store.dart';
import 'sync_models.dart';

class ActiveSyncAccountKeyNotifier extends Notifier<String?> {
  @override
  String? build() => null;
}

final activeSyncAccountKeyProvider =
    NotifierProvider<ActiveSyncAccountKeyNotifier, String?>(
      ActiveSyncAccountKeyNotifier.new,
    );

final syncCursorStoreProvider = Provider<SyncCursorStore>((ref) {
  return SyncCursorStore();
});

final syncCoordinatorProvider = Provider<SyncCoordinator>((ref) {
  return SyncCoordinator(
    ref.watch(laravelApiClientProvider),
    ref.watch(syncCursorStoreProvider),
    () => ref.read(activeSyncAccountKeyProvider),
  );
});

final syncCachedSummariesProvider =
    FutureProvider<Map<String, SyncCachedSummary>>((ref) async {
      final accountKey = ref.watch(activeSyncAccountKeyProvider);
      if (accountKey == null || accountKey.isEmpty) return const {};
      return ref.watch(syncCursorStoreProvider).readCachedSummaries(accountKey);
    });
