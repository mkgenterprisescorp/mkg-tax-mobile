import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'sync_models.dart';

abstract class SyncKeyValueStorage {
  Future<String?> read({required String key});

  Future<void> write({required String key, required String value});

  Future<void> delete({required String key});
}

class FlutterSecureSyncStorage implements SyncKeyValueStorage {
  const FlutterSecureSyncStorage([
    this._storage = const FlutterSecureStorage(),
  ]);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> write({required String key, required String value}) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);
}

class SyncCursorStore {
  SyncCursorStore([this._storage = const FlutterSecureSyncStorage()]);

  final SyncKeyValueStorage _storage;

  static const _prefix = 'mkg_sync_v1';

  Future<String?> readCursor(String accountKey) {
    return _storage.read(key: _key(accountKey, 'cursor'));
  }

  Future<void> writeCursor(String accountKey, String cursor) {
    return _storage.write(key: _key(accountKey, 'cursor'), value: cursor);
  }

  Future<Map<String, SyncCachedSummary>> readCachedSummaries(
    String accountKey,
  ) async {
    final raw = await _storage.read(key: _key(accountKey, 'summaries'));
    if (raw == null || raw.isEmpty) return const {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return const {};
    return {
      for (final entry in decoded.entries)
        if (entry.value is Map)
          '${entry.key}': SyncCachedSummary.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          ),
    };
  }

  Future<void> writeCachedSummaries(
    String accountKey,
    Map<String, SyncCachedSummary> summaries,
  ) {
    final encoded = jsonEncode({
      for (final entry in summaries.entries) entry.key: entry.value.toJson(),
    });
    return _storage.write(key: _key(accountKey, 'summaries'), value: encoded);
  }

  Future<Map<String, dynamic>?> readDashboardSnapshot(String accountKey) async {
    final raw = await _storage.read(key: _key(accountKey, 'dashboard'));
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    return Map<String, dynamic>.from(decoded);
  }

  Future<void> writeDashboardSnapshot(
    String accountKey,
    Map<String, dynamic> snapshot,
  ) {
    return _storage.write(
      key: _key(accountKey, 'dashboard'),
      value: jsonEncode(snapshot),
    );
  }

  Future<void> clearAccount(String accountKey) async {
    await Future.wait([
      _storage.delete(key: _key(accountKey, 'cursor')),
      _storage.delete(key: _key(accountKey, 'summaries')),
      _storage.delete(key: _key(accountKey, 'dashboard')),
    ]);
  }

  static String? accountKeyFor({Object? externalUserId, String? email}) {
    final id = '${externalUserId ?? ''}'.trim();
    if (id.isNotEmpty && id != 'null') return id;
    final fallback = (email ?? '').trim().toLowerCase();
    return fallback.isEmpty ? null : fallback;
  }

  static String _key(String accountKey, String suffix) {
    final encoded = base64Url
        .encode(utf8.encode(accountKey))
        .replaceAll('=', '');
    return '$_prefix:$encoded:$suffix';
  }
}
