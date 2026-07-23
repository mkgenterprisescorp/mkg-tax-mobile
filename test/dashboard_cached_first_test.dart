import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mkg_tax_mobile/core/api/portal_repository.dart';
import 'package:mkg_tax_mobile/core/network/api_client.dart';
import 'package:mkg_tax_mobile/core/network/laravel_api_client.dart';
import 'package:mkg_tax_mobile/core/sync/sync_cursor_store.dart';
import 'package:mkg_tax_mobile/core/sync/sync_providers.dart';
import 'package:mkg_tax_mobile/core/tax_year/tax_year_repository.dart';
import 'package:mkg_tax_mobile/core/theme/mkg_theme.dart';
import 'package:mkg_tax_mobile/features/auth/data/auth_repository.dart';
import 'package:mkg_tax_mobile/features/home/presentation/home_dashboard_screen.dart';

class _MemorySyncStorage implements SyncKeyValueStorage {
  final Map<String, String> values = {};

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }
}

List<TaxYearInfo> _yearsFor(int current) => List.generate(
  10,
  (i) => TaxYearInfo(
    taxYear: current - i,
    label: '${current - i}',
    isCurrentFilingYear: i == 0,
  ),
);

class _BlockedTaxYearRepository extends TaxYearRepository {
  _BlockedTaxYearRepository()
    : super(LaravelApiClient.create(baseUrl: 'http://127.0.0.1:9'));

  final gate = Completer<void>();
  int listCalls = 0;

  @override
  Future<({List<TaxYearInfo> years, int current, String source})>
  listTaxYears() async {
    listCalls++;
    await gate.future;
    final current = DateTime.now().year - 1;
    return (
      years: _yearsFor(current),
      current: current,
      source: 'test-network',
    );
  }
}

class _FakePortalRepository extends PortalRepository {
  _FakePortalRepository() : super(ApiClient.memory());

  final gate = Completer<void>();
  int getCalls = 0;

  @override
  Future<Map<String, dynamic>> getOrCreateReturnForYear(
    int year, {
    String? lastName,
  }) async {
    getCalls++;
    await gate.future;
    return {
      'id': 'network-$year',
      'year': year,
      'status': 'draft',
      'data': {'lastName': lastName ?? 'Network'},
    };
  }

  @override
  Future<List<Map<String, dynamic>>> listDocuments(dynamic returnId) async =>
      [];
}

void main() {
  testWidgets(
    'Home paints encrypted dashboard cache before network completes',
    (tester) async {
      final store = SyncCursorStore(_MemorySyncStorage());
      const user = PortalUser(
        id: 'client-1',
        email: 'alex@example.com',
        firstName: 'Alex',
        lastName: 'Client',
        role: 'client',
      );
      final accountKey = SyncCursorStore.accountKeyFor(
        externalUserId: user.id,
        email: user.email,
      )!;
      final filingYear = DateTime.now().year - 1;
      await store.writeDashboardSnapshot(
        accountKey,
        DashboardCachedSnapshot.fromState(
          TaxYearState(
            loading: false,
            years: _yearsFor(filingYear),
            currentFilingYear: filingYear,
            selectedYear: filingYear,
            catalogLoadedAt: DateTime.now(),
            workspace: TaxYearWorkspace(
              taxYear: filingYear,
              federalReturnStatus: 'Accepted',
              organizerStatus: 'In Progress',
              organizerCompletionPercentage: 67,
              documentsCount: 4,
              workspaceId: 'cached-ws',
              entityId: 'cached-entity',
            ),
            tasks: const [
              {'title': 'Upload W-2', 'href': 'documents'},
            ],
            source: 'laravel',
          ),
        ).toJson(),
      );

      final fakeRepo = _BlockedTaxYearRepository();
      final fakePortal = _FakePortalRepository();
      final container = ProviderContainer(
        overrides: [
          syncCursorStoreProvider.overrideWithValue(store),
          taxYearRepositoryProvider.overrideWithValue(fakeRepo),
          portalRepositoryProvider.overrideWithValue(fakePortal),
          apiClientProvider.overrideWithValue(ApiClient.memory()),
        ],
      );
      addTearDown(container.dispose);
      container.read(authProvider.notifier).state = const AuthState(
        loading: false,
        user: user,
      );
      container.read(activeSyncAccountKeyProvider.notifier).state = accountKey;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildMkgTheme(),
            home: const Scaffold(body: HomeDashboardScreen()),
          ),
        ),
      );
      await tester.pump();

      expect(fakeRepo.gate.isCompleted, isFalse);
      expect(fakePortal.gate.isCompleted, isFalse);
      expect(find.textContaining('Filing progress'), findsOneWidget);
      expect(find.text('Federal: Accepted'), findsOneWidget);
      expect(find.text('Organizer: In Progress'), findsOneWidget);
      expect(find.text('Docs: 4 on file'), findsOneWidget);

      fakeRepo.gate.complete();
      fakePortal.gate.complete();
      await tester.pumpAndSettle();
    },
  );
}
