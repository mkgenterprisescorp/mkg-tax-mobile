import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persisted monthly-close checklist for the current calendar month.
class BookkeepingCloseSettings {
  BookkeepingCloseSettings({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static String storageKeyFor(DateTime now) =>
      'bookkeeping_close_${now.year}_${now.month.toString().padLeft(2, '0')}';

  static const checklistIds = <String>[
    'intake',
    'bank_statements',
    'card_statements',
    'receipts',
    'payroll',
    'review',
  ];

  Future<Set<String>> loadCompleted({DateTime? now}) async {
    final key = storageKeyFor(now ?? DateTime.now());
    final raw = await _storage.read(key: key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => '$e').where(checklistIds.contains).toSet();
      }
    } catch (_) {}
    return {};
  }

  Future<void> saveCompleted(Set<String> completed, {DateTime? now}) async {
    final key = storageKeyFor(now ?? DateTime.now());
    await _storage.write(key: key, value: jsonEncode(completed.toList()..sort()));
  }
}

class BookkeepingCloseNotifier extends Notifier<Set<String>> {
  final _settings = BookkeepingCloseSettings();

  @override
  Set<String> build() {
    Future.microtask(_hydrate);
    return {};
  }

  Future<void> _hydrate() async {
    state = await _settings.loadCompleted();
  }

  Future<void> toggle(String id) async {
    if (!BookkeepingCloseSettings.checklistIds.contains(id)) return;
    final next = Set<String>.from(state);
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }
    state = next;
    await _settings.saveCompleted(next);
  }
}

final bookkeepingCloseProvider =
    NotifierProvider<BookkeepingCloseNotifier, Set<String>>(BookkeepingCloseNotifier.new);
