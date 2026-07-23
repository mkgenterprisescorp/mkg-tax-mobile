import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mkg_tax_mobile/core/network/laravel_api_client.dart';
import 'package:mkg_tax_mobile/core/sync/sync_coordinator.dart';
import 'package:mkg_tax_mobile/core/sync/sync_cursor_store.dart';
import 'package:mkg_tax_mobile/core/sync/sync_models.dart';

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

class _QueuedResponse {
  const _QueuedResponse(this.statusCode, this.body);

  final int statusCode;
  final Map<String, dynamic> body;
}

class _QueuedAdapter implements HttpClientAdapter {
  final Queue<Future<_QueuedResponse>> responses =
      Queue<Future<_QueuedResponse>>();
  final List<RequestOptions> requests = [];

  void enqueue(Map<String, dynamic> body, {int statusCode = 200}) {
    responses.add(Future.value(_QueuedResponse(statusCode, body)));
  }

  void enqueueFuture(Future<_QueuedResponse> response) {
    responses.add(response);
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final response = await responses.removeFirst();
    return ResponseBody.fromString(
      jsonEncode(response.body),
      response.statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

({SyncCoordinator coordinator, SyncCursorStore store, _QueuedAdapter adapter})
_makeCoordinator({String accountKey = 'external-1'}) {
  final adapter = _QueuedAdapter();
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://app.mkgtaxconsultants.com',
      validateStatus: (code) => code != null && code < 500,
    ),
  )..httpClientAdapter = adapter;
  final api = LaravelApiClient(dio)..setBearerToken('token');
  final store = SyncCursorStore(_MemorySyncStorage());
  final coordinator = SyncCoordinator(
    api,
    store,
    () => accountKey,
    retryBaseDelay: Duration.zero,
  );
  return (coordinator: coordinator, store: store, adapter: adapter);
}

Map<String, dynamic> _event({
  required String entityType,
  required String entityId,
  required int entityVersion,
  Map<String, dynamic> summary = const {},
}) {
  return {
    'schema_version': syncSchemaVersion,
    'event_id': '$entityType-$entityId-$entityVersion',
    'entity_type': entityType,
    'entity_id': entityId,
    'entity_version': entityVersion,
    'summary': summary,
  };
}

void main() {
  test('coalesces simultaneous pulls into one HTTP request', () async {
    final subject = _makeCoordinator();
    final gate = Completer<_QueuedResponse>();
    subject.adapter.enqueueFuture(gate.future);

    final first = subject.coordinator.pull(reason: 'manual');
    final second = subject.coordinator.pull(reason: 'resume');

    expect(identical(first, second), isTrue);
    expect(subject.coordinator.debugPullInFlight, isTrue);
    for (var i = 0; i < 5 && subject.adapter.requests.isEmpty; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(subject.adapter.requests, hasLength(1));

    gate.complete(
      const _QueuedResponse(200, {'events': [], 'next_cursor': 'cursor-1'}),
    );
    await first;

    expect(subject.coordinator.debugPullInFlight, isFalse);
    expect(await subject.store.readCursor('external-1'), 'cursor-1');
  });

  test('persists next cursor and sends it on the next pull', () async {
    final subject = _makeCoordinator();
    subject.adapter.enqueue({'events': [], 'next_cursor': 'signed-cursor-a'});

    await subject.coordinator.pull(reason: 'login');

    expect(await subject.store.readCursor('external-1'), 'signed-cursor-a');

    subject.adapter.enqueue({'events': [], 'next_cursor': 'signed-cursor-b'});
    await subject.coordinator.pull(reason: 'manual');

    expect(
      subject.adapter.requests.last.queryParameters['cursor'],
      'signed-cursor-a',
    );
    expect(await subject.store.readCursor('external-1'), 'signed-cursor-b');
  });

  test('logout clears cursor and cached summaries for account', () async {
    final subject = _makeCoordinator();
    await subject.store.writeCursor('external-1', 'signed-cursor');
    await subject.store.writeCachedSummaries('external-1', {
      'profile:external-1': SyncCachedSummary(
        entityType: 'profile',
        entityId: 'external-1',
        entityVersion: 2,
        data: const {'name': 'Alex'},
        updatedAt: DateTime.utc(2026),
      ),
    });

    await subject.coordinator.clearAccount(accountKey: 'external-1');

    expect(await subject.store.readCursor('external-1'), isNull);
    expect(await subject.store.readCachedSummaries('external-1'), isEmpty);
  });

  test(
    'applies server changes by entity_version and skips older events',
    () async {
      final subject = _makeCoordinator();
      subject.adapter.enqueue({
        'events': [
          _event(
            entityType: 'profile',
            entityId: 'external-1',
            entityVersion: 5,
            summary: const {'name': 'Server Fresh'},
          ),
        ],
        'next_cursor': 'cursor-5',
      });
      await subject.coordinator.pull(reason: 'login');

      subject.adapter.enqueue({
        'events': [
          _event(
            entityType: 'profile',
            entityId: 'external-1',
            entityVersion: 4,
            summary: const {'name': 'Older Server'},
          ),
        ],
        'next_cursor': 'cursor-4',
      });
      await subject.coordinator.pull(reason: 'manual');

      final summaries = await subject.store.readCachedSummaries('external-1');
      final profile = summaries['profile:external-1'];
      expect(profile?.entityVersion, 5);
      expect(profile?.data['name'], 'Server Fresh');
    },
  );

  test('does not create a polling timer', () async {
    final subject = _makeCoordinator();
    subject.adapter.enqueue({'events': [], 'next_cursor': 'cursor-1'});

    expect(subject.coordinator.debugHasPollingTimer, isFalse);
    await subject.coordinator.pull(reason: 'manual');
    expect(subject.coordinator.debugHasPollingTimer, isFalse);
  });
}
