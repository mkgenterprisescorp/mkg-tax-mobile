import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/laravel_api_client.dart';
import '../../../core/platform/platform_api.dart';
import '../../auth/data/auth_repository.dart';

/// Values pulled from the signed-in account for organizer auto-fill.
class OrganizerProfilePrefill {
  const OrganizerProfilePrefill({
    this.firstName = '',
    this.lastName = '',
    this.email = '',
    this.phone = '',
    this.address = '',
    this.apartment = '',
    this.city = '',
    this.state = '',
    this.zip = '',
  });

  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String address;
  final String apartment;
  final String city;
  final String state;
  final String zip;

  bool get hasAnyIdentity =>
      firstName.isNotEmpty || lastName.isNotEmpty || email.isNotEmpty || phone.isNotEmpty;

  bool get hasAnyAddress =>
      address.isNotEmpty || city.isNotEmpty || state.isNotEmpty || zip.isNotEmpty;

  /// Merge profile values into organizer data. Never overwrites non-empty fields
  /// unless [overwrite] is true (used when the user explicitly turns the toggle on).
  Map<String, dynamic> applyTo(
    Map<String, dynamic> data, {
    bool overwrite = false,
  }) {
    final next = Map<String, dynamic>.from(data);
    void put(String key, String value) {
      if (value.isEmpty) return;
      final current = '${next[key] ?? ''}'.trim();
      if (overwrite || current.isEmpty) next[key] = value;
    }

    put('firstName', firstName);
    put('lastName', lastName);
    put('email', email);
    put('phone', phone);
    put('address', address);
    put('apartment', apartment);
    put('city', city);
    put('state', state);
    put('zip', zip);
    return next;
  }
}

class OrganizerProfilePrefillRepository {
  OrganizerProfilePrefillRepository(this._auth, this._laravel);

  final AuthRepository _auth;
  final LaravelApiClient _laravel;

  Future<OrganizerProfilePrefill> load() async {
    final user = await _auth.currentUser();
    var first = user?.firstName.trim() ?? '';
    var last = user?.lastName.trim() ?? '';
    var email = user?.email.trim() ?? '';
    var phone = user?.phone?.trim() ?? '';
    var address = user?.address?.trim() ?? '';
    var apartment = '';
    var city = user?.city?.trim() ?? '';
    var state = user?.state?.trim() ?? '';
    var zip = user?.zipCode?.trim() ?? '';

    if (AppConfig.usesLaravelAuth && _laravel.bearerToken != null) {
      try {
        final res = await _laravel.get<Map<String, dynamic>>('/api/v1/profile');
        if (PlatformApi.ok(res)) {
          final data = PlatformApi.unwrapMap(res) ?? const {};
          final name = '${data['name'] ?? data['preferred_name'] ?? ''}'.trim();
          if (first.isEmpty && last.isEmpty && name.isNotEmpty) {
            final parts = name.split(RegExp(r'\s+'));
            first = parts.first;
            last = parts.length > 1 ? parts.sublist(1).join(' ') : '';
          }
          email = email.isNotEmpty ? email : '${data['email'] ?? ''}'.trim();
          phone = phone.isNotEmpty ? phone : '${data['phone'] ?? ''}'.trim();
          final mailing = data['mailing_address'];
          if (mailing is Map) {
            final m = Map<String, dynamic>.from(mailing);
            address = address.isNotEmpty ? address : '${m['line1'] ?? ''}'.trim();
            apartment = '${m['line2'] ?? ''}'.trim();
            city = city.isNotEmpty ? city : '${m['city'] ?? ''}'.trim();
            state = state.isNotEmpty ? state : '${m['state'] ?? ''}'.trim();
            zip = zip.isNotEmpty ? zip : '${m['postal_code'] ?? m['zip'] ?? ''}'.trim();
          }
        }
      } catch (_) {
        // Prefer auth claims when profile endpoint is unavailable.
      }
    }

    return OrganizerProfilePrefill(
      firstName: first,
      lastName: last,
      email: email,
      phone: phone,
      address: address,
      apartment: apartment,
      city: city,
      state: state,
      zip: zip,
    );
  }

  Map<String, dynamic> applyTo(
    Map<String, dynamic> data,
    OrganizerProfilePrefill prefill, {
    bool overwrite = false,
  }) {
    return prefill.applyTo(data, overwrite: overwrite);
  }
}

final organizerProfilePrefillRepositoryProvider = Provider<OrganizerProfilePrefillRepository>((ref) {
  return OrganizerProfilePrefillRepository(
    ref.watch(authRepositoryProvider),
    ref.watch(laravelApiClientProvider),
  );
});
