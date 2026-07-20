import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mkg_tax_mobile/core/api/portal_repository.dart';
import 'package:mkg_tax_mobile/core/network/api_client.dart';
import 'package:mkg_tax_mobile/core/network/laravel_api_client.dart';
import 'package:mkg_tax_mobile/core/tax_year/tax_year_repository.dart';
import 'package:mkg_tax_mobile/core/theme/mkg_theme.dart';
import 'package:mkg_tax_mobile/core/widgets/mkg_widgets.dart';
import 'package:mkg_tax_mobile/features/auth/data/auth_repository.dart';
import 'package:mkg_tax_mobile/features/home/presentation/home_dashboard_screen.dart';

List<TaxYearInfo> _yearsFor(int current) => List.generate(
      10,
      (i) => TaxYearInfo(
        taxYear: current - i,
        label: '${current - i}',
        isCurrentFilingYear: i == 0,
      ),
    );

class _FakeTaxYearRepository extends TaxYearRepository {
  _FakeTaxYearRepository()
      : super(LaravelApiClient.create(baseUrl: 'http://127.0.0.1:9'));

  int listCalls = 0;
  Completer<void>? gate;
  Object? throwOnList;
  int catalogCurrent = DateTime.now().year - 1;

  @override
  Future<({List<TaxYearInfo> years, int current, String source})> listTaxYears() async {
    listCalls++;
    final g = gate;
    if (g != null) await g.future;
    final err = throwOnList;
    if (err != null) throw err;
    return (
      years: _yearsFor(catalogCurrent),
      current: catalogCurrent,
      source: 'test-fake',
    );
  }
}

class _FakePortalRepository extends PortalRepository {
  _FakePortalRepository() : super(ApiClient.memory());

  Object? throwOnGet;
  int getCalls = 0;

  @override
  Future<Map<String, dynamic>> getOrCreateReturnForYear(
    int year, {
    String? lastName,
  }) async {
    getCalls++;
    final err = throwOnGet;
    if (err != null) throw err;
    return {
      'id': 'ret-$year',
      'year': year,
      'status': 'draft',
      'data': {'lastName': lastName ?? 'Test'},
    };
  }

  @override
  Future<List<Map<String, dynamic>>> listDocuments(dynamic returnId) async => [];
}

void main() {
  group('isTaxYearCatalogWarm', () {
    test('requires season match and loaded-at within TTL', () {
      final now = DateTime(2026, 7, 20);
      final warm = TaxYearState(
        years: _yearsFor(2025),
        currentFilingYear: 2025,
        catalogLoadedAt: now.subtract(const Duration(hours: 1)),
      );
      expect(isTaxYearCatalogWarm(warm, now: now), isTrue);

      final staleSeason = warm.copyWith(currentFilingYear: 2024);
      expect(isTaxYearCatalogWarm(staleSeason, now: now), isFalse);

      final expiredTtl = TaxYearState(
        years: _yearsFor(2025),
        currentFilingYear: 2025,
        catalogLoadedAt: now.subtract(const Duration(hours: 13)),
      );
      expect(isTaxYearCatalogWarm(expiredTtl, now: now), isFalse);

      final missingLoadedAt = TaxYearState(
        years: _yearsFor(2025),
        currentFilingYear: 2025,
      );
      expect(isTaxYearCatalogWarm(missingLoadedAt, now: now), isFalse);
    });

    test('year rollover invalidates warm catalog even within TTL', () {
      final lateSeason = DateTime(2026, 12, 31, 23, 0);
      final afterRollover = DateTime(2027, 1, 1, 0, 30);
      final state = TaxYearState(
        years: _yearsFor(2025),
        currentFilingYear: 2025,
        catalogLoadedAt: lateSeason,
      );
      expect(isTaxYearCatalogWarm(state, now: lateSeason), isTrue);
      // Local expected filing year becomes 2026 after calendar rollover.
      expect(isTaxYearCatalogWarm(state, now: afterRollover), isFalse);
    });
  });

  group('bootstrap in-flight dedupe', () {
    late _FakeTaxYearRepository fakeRepo;
    late _FakePortalRepository fakePortal;
    late ProviderContainer container;

    setUp(() {
      fakeRepo = _FakeTaxYearRepository();
      fakePortal = _FakePortalRepository();
      container = ProviderContainer(
        overrides: [
          taxYearRepositoryProvider.overrideWithValue(fakeRepo),
          portalRepositoryProvider.overrideWithValue(fakePortal),
          apiClientProvider.overrideWithValue(ApiClient.memory()),
        ],
      );
      addTearDown(container.dispose);
    });

    test('success path clears in-flight and allows a second bootstrap', () async {
      final notifier = container.read(taxYearProvider.notifier);
      final first = notifier.bootstrap(forceCatalog: true);
      expect(notifier.debugBootstrapInFlight, isTrue);
      // Stored Future must be the exact instance returned to callers.
      expect(identical(first, notifier.debugBootstrapInFlightFuture), isTrue);
      await first;
      expect(notifier.debugBootstrapInFlight, isFalse);
      expect(notifier.debugBootstrapInFlightFuture, isNull);
      expect(fakeRepo.listCalls, 1);
      expect(container.read(taxYearProvider).error, isNull);
      expect(container.read(taxYearProvider).catalogLoadedAt, isNotNull);

      final second = notifier.bootstrap(forceCatalog: true);
      expect(identical(first, second), isFalse);
      expect(identical(second, notifier.debugBootstrapInFlightFuture), isTrue);
      await second;
      expect(notifier.debugBootstrapInFlight, isFalse);
      expect(fakeRepo.listCalls, 2);
    });

    test('exception path still clears in-flight for a subsequent bootstrap', () async {
      fakeRepo.throwOnList = StateError('catalog unavailable');
      final notifier = container.read(taxYearProvider.notifier);

      final failed = notifier.bootstrap(forceCatalog: true);
      expect(identical(failed, notifier.debugBootstrapInFlightFuture), isTrue);
      await failed;
      expect(notifier.debugBootstrapInFlight, isFalse);
      expect(notifier.debugBootstrapInFlightFuture, isNull);
      expect(container.read(taxYearProvider).error, isNotNull);
      expect(fakeRepo.listCalls, 1);

      fakeRepo.throwOnList = null;
      final recovered = notifier.bootstrap(forceCatalog: true);
      expect(identical(failed, recovered), isFalse);
      expect(identical(recovered, notifier.debugBootstrapInFlightFuture), isTrue);
      await recovered;
      expect(notifier.debugBootstrapInFlight, isFalse);
      expect(fakeRepo.listCalls, 2);
      expect(container.read(taxYearProvider).error, isNull);
    });

    test('concurrent callers share one Future and clear after completion', () async {
      fakeRepo.gate = Completer<void>();
      final notifier = container.read(taxYearProvider.notifier);

      final a = notifier.bootstrap(forceCatalog: true);
      final b = notifier.bootstrap(forceCatalog: true);
      expect(identical(a, b), isTrue);
      expect(identical(a, notifier.debugBootstrapInFlightFuture), isTrue);
      expect(fakeRepo.listCalls, 1);
      expect(notifier.debugBootstrapInFlight, isTrue);

      fakeRepo.gate!.complete();
      await a;
      expect(notifier.debugBootstrapInFlight, isFalse);
      expect(notifier.debugBootstrapInFlightFuture, isNull);

      final c = notifier.bootstrap(forceCatalog: true);
      expect(identical(a, c), isFalse);
      await c;
      expect(fakeRepo.listCalls, 2);
    });

    test('soft-refresh failure keeps warm catalog and records error', () async {
      final notifier = container.read(taxYearProvider.notifier);
      await notifier.bootstrap(forceCatalog: true);
      expect(isTaxYearCatalogWarm(container.read(taxYearProvider)), isTrue);
      final listBefore = fakeRepo.listCalls;

      fakePortal.throwOnGet = StateError('workspace soft-refresh failed');
      await notifier.bootstrap();
      final state = container.read(taxYearProvider);
      // Warm catalog still skips GET /tax-years on soft remount.
      expect(fakeRepo.listCalls, listBefore);
      expect(state.error, isNotNull);
      expect(state.years, isNotEmpty);
      expect(notifier.debugBootstrapInFlight, isFalse);
    });

    test('stale filing season forces catalog refetch on remount', () async {
      final notifier = container.read(taxYearProvider.notifier);
      await notifier.bootstrap(forceCatalog: true);
      final listAfterWarm = fakeRepo.listCalls;

      // Simulate a catalog that survived past year rollover in memory.
      notifier.state = container.read(taxYearProvider).copyWith(
            currentFilingYear: DateTime.now().year - 2,
            catalogLoadedAt: DateTime.now(),
          );
      expect(isTaxYearCatalogWarm(container.read(taxYearProvider)), isFalse);

      await notifier.bootstrap();
      expect(fakeRepo.listCalls, listAfterWarm + 1);
      expect(
        container.read(taxYearProvider).currentFilingYear,
        DateTime.now().year - 1,
      );
    });
  });

  group('organizer snapshot scope', () {
    TaxYearState seeded({
      required String workspaceId,
      required String entityId,
      required int taxYear,
    }) {
      return TaxYearState(
        selectedYear: taxYear,
        currentFilingYear: taxYear,
        workspace: TaxYearWorkspace(
          taxYear: taxYear,
          federalReturnStatus: 'Not Started',
          organizerStatus: 'In Progress',
          organizerCompletionPercentage: 10,
          workspaceId: workspaceId,
          entityId: entityId,
        ),
        organizerSnapshot: {
          'id': 'org-1',
          'tax_year_workspace_id': workspaceId,
          'prep_type': 'personal',
        },
        organizerSnapshotScope: OrganizerSnapshotScope(
          workspaceId: workspaceId,
          entityId: entityId,
          taxYear: taxYear,
        ),
      );
    }

    test('selected tax year change clears snapshot via clearWorkspace', () {
      final before = seeded(workspaceId: 'ws-a', entityId: 'ent-1', taxYear: 2025);
      expect(before.scopedOrganizerSnapshot, isNotNull);

      final after = before.copyWith(selectedYear: 2024, clearWorkspace: true);
      expect(after.workspace, isNull);
      expect(after.organizerSnapshot, isNull);
      expect(after.organizerSnapshotScope, isNull);
      expect(after.scopedOrganizerSnapshot, isNull);
    });

    test('workspace change without matching scope rejects reuse', () {
      final before = seeded(workspaceId: 'ws-a', entityId: 'ent-1', taxYear: 2025);
      final swapped = before.copyWith(
        workspace: TaxYearWorkspace(
          taxYear: 2025,
          federalReturnStatus: 'Not Started',
          organizerStatus: 'In Progress',
          organizerCompletionPercentage: 10,
          workspaceId: 'ws-b',
          entityId: 'ent-1',
        ),
      );
      // Global map may still be present, but scoped accessor must refuse it.
      expect(swapped.organizerSnapshot, isNotNull);
      expect(swapped.scopedOrganizerSnapshot, isNull);
    });

    test('taxpayer/entity change rejects scoped snapshot reuse', () {
      final before = seeded(workspaceId: 'ws-a', entityId: 'ent-1', taxYear: 2025);
      final swapped = before.copyWith(
        workspace: TaxYearWorkspace(
          taxYear: 2025,
          federalReturnStatus: 'Not Started',
          organizerStatus: 'In Progress',
          organizerCompletionPercentage: 10,
          workspaceId: 'ws-a',
          entityId: 'ent-2',
        ),
      );
      expect(swapped.organizerSnapshot, isNotNull);
      expect(swapped.scopedOrganizerSnapshot, isNull);
    });

    test('explicit Save invalidation clears snapshot', () {
      final before = seeded(workspaceId: 'ws-a', entityId: 'ent-1', taxYear: 2025);
      final after = before.copyWith(clearOrganizerSnapshot: true);
      expect(after.organizerSnapshot, isNull);
      expect(after.organizerSnapshotScope, isNull);
      // Workspace content remains for Home / Organizer navigation.
      expect(after.workspace?.workspaceId, 'ws-a');
    });

    test('silent autosave retention keeps scoped snapshot', () {
      final before = seeded(workspaceId: 'ws-a', entityId: 'ent-1', taxYear: 2025);
      // Silent path does not call clearOrganizerSnapshot — state unchanged.
      final afterSilent = before.copyWith(loading: false, error: null);
      expect(afterSilent.organizerSnapshot, isNotNull);
      expect(afterSilent.scopedOrganizerSnapshot?['tax_year_workspace_id'], 'ws-a');
      expect(afterSilent.organizerSnapshotScope?.entityId, 'ent-1');
      expect(afterSilent.organizerSnapshotScope?.taxYear, 2025);
    });

    test('clearOrganizerSnapshot on notifier drops cached activate JSON', () {
      final fakeRepo = _FakeTaxYearRepository();
      final fakePortal = _FakePortalRepository();
      final container = ProviderContainer(
        overrides: [
          taxYearRepositoryProvider.overrideWithValue(fakeRepo),
          portalRepositoryProvider.overrideWithValue(fakePortal),
          apiClientProvider.overrideWithValue(ApiClient.memory()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(taxYearProvider.notifier);
      notifier.state = seeded(workspaceId: 'ws-a', entityId: 'ent-1', taxYear: 2025);
      expect(container.read(taxYearProvider).organizerSnapshot, isNotNull);

      notifier.clearOrganizerSnapshot();
      expect(container.read(taxYearProvider).organizerSnapshot, isNull);
      expect(container.read(taxYearProvider).organizerSnapshotScope, isNull);
      expect(container.read(taxYearProvider).workspace?.workspaceId, 'ws-a');
    });
  });

  testWidgets('Home shows non-blocking soft-refresh error banner with Retry', (tester) async {
    final fakeRepo = _FakeTaxYearRepository();
    final fakePortal = _FakePortalRepository();
    final container = ProviderContainer(
      overrides: [
        taxYearRepositoryProvider.overrideWithValue(fakeRepo),
        portalRepositoryProvider.overrideWithValue(fakePortal),
        apiClientProvider.overrideWithValue(ApiClient.memory()),
      ],
    );
    addTearDown(() {
      container.dispose();
    });

    container.read(authProvider.notifier).state = const AuthState(
      loading: false,
      user: PortalUser(
        id: 'u1',
        email: 'client@example.com',
        firstName: 'Alex',
        lastName: 'Client',
        role: 'client',
      ),
    );

    final filingYear = DateTime.now().year - 1;
    // Seed warm workspace + soft-refresh error before first frame so Home paints
    // the banner without waiting on network/bootstrap side effects.
    container.read(taxYearProvider.notifier).state = TaxYearState(
      loading: false,
      years: _yearsFor(filingYear),
      currentFilingYear: filingYear,
      selectedYear: filingYear,
      catalogLoadedAt: DateTime.now(),
      workspace: TaxYearWorkspace(
        taxYear: filingYear,
        federalReturnStatus: 'Not Started',
        organizerStatus: 'In Progress',
        organizerCompletionPercentage: 40,
        workspaceId: 'ws-home',
        entityId: 'ent-home',
      ),
      error: 'Could not refresh your tax year workspace.',
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildMkgTheme(),
          home: const Scaffold(body: HomeDashboardScreen()),
        ),
      ),
    );
    await tester.pump(); // build + schedule post-frame bootstrap
    // Restore soft-refresh error if post-frame bootstrap cleared it.
    container.read(taxYearProvider.notifier).state = container.read(taxYearProvider).copyWith(
          error: 'Could not refresh your tax year workspace.',
          workspace: TaxYearWorkspace(
            taxYear: filingYear,
            federalReturnStatus: 'Not Started',
            organizerStatus: 'In Progress',
            organizerCompletionPercentage: 40,
            workspaceId: 'ws-home',
            entityId: 'ent-home',
          ),
          loading: false,
        );
    await tester.pump();

    expect(find.byType(MkgErrorBanner), findsOneWidget);
    expect(find.text('Could not refresh your tax year workspace.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('Filing progress'), findsOneWidget);

    // Drain Riverpod retry timers from incidental provider mounts.
    await tester.pump(const Duration(seconds: 1));
  });
}
