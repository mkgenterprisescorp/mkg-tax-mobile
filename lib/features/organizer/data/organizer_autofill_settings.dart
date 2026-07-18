import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persisted preference: auto-fill organizer taxpayer fields from the signed-in profile.
class OrganizerAutofillSettings {
  OrganizerAutofillSettings({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const storageKey = 'organizer_autofill_profile_enabled';

  final FlutterSecureStorage _storage;

  Future<bool> isEnabled() async {
    final raw = await _storage.read(key: storageKey);
    if (raw == null) return true; // default ON to reduce repetitive typing
    return raw == '1' || raw.toLowerCase() == 'true';
  }

  Future<void> setEnabled(bool enabled) async {
    await _storage.write(key: storageKey, value: enabled ? '1' : '0');
  }
}

class OrganizerAutofillNotifier extends Notifier<bool> {
  final _settings = OrganizerAutofillSettings();

  @override
  bool build() {
    Future.microtask(_hydrate);
    return true;
  }

  Future<void> _hydrate() async {
    state = await _settings.isEnabled();
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await _settings.setEnabled(enabled);
  }
}

final organizerAutofillEnabledProvider =
    NotifierProvider<OrganizerAutofillNotifier, bool>(OrganizerAutofillNotifier.new);
