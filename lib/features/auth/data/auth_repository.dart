import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../core/network/laravel_api_client.dart';

class PortalUser {
  const PortalUser({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.phone,
    this.role,
    this.kycStatus,
    this.approvalStatus,
    this.address,
    this.city,
    this.state,
    this.zipCode,
    this.last4ssn,
    this.createdAt,
    this.enochAcknowledged,
    this.tutorialWatched,
  });

  final dynamic id;
  final String email;
  final String firstName;
  final String lastName;
  final String? phone;
  final String? role;
  final String? kycStatus;
  final String? approvalStatus;
  final String? address;
  final String? city;
  final String? state;
  final String? zipCode;
  final String? last4ssn;
  final String? createdAt;
  final bool? enochAcknowledged;
  final bool? tutorialWatched;

  String get displayName {
    final name = '$firstName $lastName'.trim();
    return name.isEmpty ? email : name;
  }

  factory PortalUser.fromJson(Map<String, dynamic> json) {
    final name = (json['name'] ?? '').toString().trim();
    var first = (json['firstName'] ?? json['first_name'] ?? '').toString();
    var last = (json['lastName'] ?? json['last_name'] ?? '').toString();
    if (first.isEmpty && last.isEmpty && name.isNotEmpty) {
      final parts = name.split(RegExp(r'\s+'));
      first = parts.first;
      last = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    }
    return PortalUser(
      id: json['id'],
      email: (json['email'] ?? '').toString(),
      firstName: first,
      lastName: last,
      phone: json['phone']?.toString(),
      role: json['role']?.toString(),
      kycStatus: json['kycStatus']?.toString() ?? json['kyc_status']?.toString(),
      approvalStatus: json['approvalStatus']?.toString() ?? json['approval_status']?.toString(),
      address: json['address']?.toString(),
      city: json['city']?.toString(),
      state: json['state']?.toString(),
      zipCode: json['zipCode']?.toString() ?? json['zip_code']?.toString(),
      last4ssn: json['last4ssn']?.toString() ?? json['last_4_ssn']?.toString(),
      createdAt: json['createdAt']?.toString() ?? json['created_at']?.toString(),
      enochAcknowledged: json['enochAcknowledged'] as bool? ?? json['enoch_acknowledged'] as bool?,
      tutorialWatched: json['tutorialWatched'] as bool? ?? json['tutorial_watched'] as bool?,
    );
  }

  /// Map Laravel `/api/v1/profile` payload onto [PortalUser] for local session.
  factory PortalUser.fromLaravelProfile(
    Map<String, dynamic> profile, {
    PortalUser? fallback,
  }) {
    final mailing = profile['mailing_address'] is Map
        ? Map<String, dynamic>.from(profile['mailing_address'] as Map)
        : const <String, dynamic>{};
    final approval = profile['approval_status']?.toString() ?? fallback?.approvalStatus;
    final verification = profile['verification'] is Map
        ? Map<String, dynamic>.from(profile['verification'] as Map)
        : const <String, dynamic>{};
    final phoneVerified = verification['phone'] == true;
    final emailVerified = verification['email'] == true;
    // Soft-gate uses kycStatus; profile bridge has no dedicated KYC field.
    final kyc = approval == 'approved'
        ? 'approved'
        : (phoneVerified || emailVerified || '${mailing['line1'] ?? ''}'.trim().isNotEmpty)
            ? 'submitted'
            : (fallback?.kycStatus ?? 'incomplete');
    final identity = profile['identity_verification'];
    final identityStatus = identity is Map ? identity['status']?.toString() : null;
    final resolvedKyc = profile['kyc_status']?.toString() ?? identityStatus ?? kyc;
    return PortalUser.fromJson({
      ...profile,
      'id': profile['external_user_id'] ?? fallback?.id,
      'firstName': profile['first_name'] ?? profile['firstName'] ?? fallback?.firstName,
      'lastName': profile['last_name'] ?? profile['lastName'] ?? fallback?.lastName,
      'name': profile['name'] ?? profile['preferred_name'] ?? fallback?.displayName,
      'approval_status': approval,
      'kyc_status': resolvedKyc,
      'address': mailing['line1'] ?? fallback?.address,
      'city': mailing['city'] ?? fallback?.city,
      'state': mailing['state'] ?? fallback?.state,
      'zip_code': mailing['postal_code'] ?? mailing['zip'] ?? fallback?.zipCode,
      'phone': profile['phone'] ?? fallback?.phone,
      'email': profile['email'] ?? fallback?.email,
    });
  }
}

class AuthException implements Exception {
  AuthException(this.message, {this.requires2FA = false, this.requiresOtp = false});
  final String message;
  final bool requires2FA;
  final bool requiresOtp;
  @override
  String toString() => message;
}

/// Safe, non-server-controlled message for an auth API failure. Never
/// forwards `data['message']`/`data['error']` from the response body — those
/// fields are server-authored free text and must not reach the UI directly
/// (see ApiErrorMapper for why). Falls back to [fallback] — a fixed,
/// developer-authored string — when the status code has no specific mapping.
String _authErrorMessage(int? statusCode, String fallback) {
  final mapped = ApiErrorMapper.mapStatusCode(statusCode);
  return mapped == ApiErrorMapper.genericMessage ? fallback : mapped;
}

String _loginErrorMessage(int? statusCode) {
  return ApiErrorMapper.mapLoginStatusCode(statusCode);
}

/// Uniform acknowledgement for the forgot-password request step.
/// Identical for every transport/server outcome (2xx, 4xx, 5xx, timeout,
/// connection failure, malformed body). Never derived from a response body.
const String passwordResetAcknowledgement =
    'If an account matches the information provided, password reset instructions will be sent.';

class AuthRepository {
  AuthRepository(this._api, {LaravelApiClient? laravel}) : _laravel = laravel;

  final ApiClient _api;
  final LaravelApiClient? _laravel;
  static const _tokenKey = 'mkg_sanctum_token';
  static const _storage = FlutterSecureStorage();

  Future<void> _persistToken(String? token) async {
    if (token == null || token.isEmpty) {
      await _storage.delete(key: _tokenKey);
      _laravel?.setBearerToken(null);
      return;
    }
    await _storage.write(key: _tokenKey, value: token);
    _laravel?.setBearerToken(token);
    _api.dio.options.headers['Authorization'] = 'Bearer $token';
  }

  Future<String?> _readToken() async {
    final token = await _storage.read(key: _tokenKey);
    if (token != null && token.isNotEmpty) {
      _laravel?.setBearerToken(token);
      _api.dio.options.headers['Authorization'] = 'Bearer $token';
    }
    return token;
  }

  Future<PortalUser?> currentUser() async {
    if (AppConfig.usesLaravelAuth) {
      await _readToken();
      final res = await _api.get<Map<String, dynamic>>('/me');
      if (res.statusCode == 401 || res.data == null) return null;
      if (res.statusCode != 200) return null;
      final raw = res.data!;
      // Laravel returns { external_user_id, claims, session_expires_at } (no data envelope).
      final claims = raw['claims'] is Map
          ? Map<String, dynamic>.from(raw['claims'] as Map)
          : <String, dynamic>{};
      final userMap = <String, dynamic>{
        'id': raw['external_user_id'] ?? claims['external_user_id'],
        'email': claims['email'] ?? raw['email'] ?? '',
        'name': claims['name'] ?? raw['name'] ?? '',
        'role': claims['role'] ?? raw['role'],
        ...claims,
        ...raw,
      };
      return PortalUser.fromJson(userMap);
    }

    final res = await _api.get<Map<String, dynamic>>('/api/auth/user');
    if (res.statusCode == 401 || res.data == null) return null;
    if (res.statusCode != 200) return null;
    return PortalUser.fromJson(Map<String, dynamic>.from(res.data!));
  }

  Future<PortalUser> login({
    required String email,
    required String password,
  }) async {
    if (AppConfig.usesLaravelAuth) {
      final res = await _api.post<Map<String, dynamic>>(
        '/auth/login',
        data: {
          'identifier': email.trim(),
          'password': password,
          'device_name': 'mkg-tax-mobile',
        },
      );
      final data = res.data ?? {};
      if (res.statusCode == 200) {
        final token = (data['token'] ?? '').toString();
        if (token.isEmpty) {
          throw AuthException(ApiErrorMapper.loginServerUnavailableMessage);
        }
        await _persistToken(token);
        final userMap = data['user'] is Map
            ? Map<String, dynamic>.from(data['user'] as Map)
            : Map<String, dynamic>.from(data);
        // Normalize identity claims shape for PortalUser.
        if (userMap['email'] == null && userMap['external_user_id'] != null) {
          userMap['email'] = email.trim();
        }
        if (userMap['id'] == null) {
          userMap['id'] = userMap['external_user_id'];
        }
        return PortalUser.fromJson(userMap);
      }
      throw AuthException(_loginErrorMessage(res.statusCode));
    }

    final res = await _api.post<Map<String, dynamic>>(
      '/api/login',
      data: {'email': email.trim(), 'password': password},
    );
    final data = res.data ?? {};
    if (res.statusCode == 200) {
      if (data['requires2FA'] == true || data['totpPending'] == true) {
        throw AuthException(
          'Two-factor authentication is required. Please complete verification to continue.',
          requires2FA: true,
        );
      }
      if (data['requiresPasswordSetup'] == true) {
        throw AuthException(
          'Password setup is required before you can sign in. Please contact MKG Tax Consultants for assistance.',
        );
      }
      return PortalUser.fromJson(Map<String, dynamic>.from(data));
    }
    throw AuthException(_loginErrorMessage(res.statusCode));
  }

  /// Client-facing copy when online registration is disabled for this build.
  static const registrationUnavailableMessage =
      'Online account registration is not available in this testing version. Please contact MKG Tax Consultants for assistance.';

  Future<PortalUser> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
    String? referralCode,
  }) async {
    if (AppConfig.usesLaravelAuth) {
      throw AuthException(registrationUnavailableMessage);
    }

    final res = await _api.post<Map<String, dynamic>>(
      '/api/register',
      data: {
        'email': email.trim(),
        'password': password,
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'phone': phone.trim(),
        'role': 'client',
        if (referralCode != null && referralCode.trim().isNotEmpty) 'referralCode': referralCode.trim(),
      },
    );
    final data = res.data ?? {};
    if (res.statusCode == 200 || res.statusCode == 201) {
      return PortalUser.fromJson(Map<String, dynamic>.from(data));
    }
    throw AuthException(_authErrorMessage(res.statusCode, 'Registration failed. Please try again.'));
  }

  /// Step 1 of password reset: request a code / instructions.
  ///
  /// Completes successfully for every observable outcome — including HTTP
  /// statuses that Dio throws as [DioException.badResponse] (500/503 under
  /// `validateStatus: code < 500`), timeouts, and connection failures.
  /// Callers must never branch on success vs failure for this method; the
  /// UI always shows [passwordResetAcknowledgement] and the same navigation.
  Future<void> requestPasswordReset(String email) async {
    try {
      if (AppConfig.usesLaravelAuth) {
        // Enumeration-safe façade → mkgtaxconsultants.com portal via mobile API.
        await _api.post<Map<String, dynamic>>(
          '/auth/password-reset/request',
          data: {'email': email.trim()},
        );
      } else {
        // Fire-and-forget from the client's perspective: status codes and
        // response bodies are intentionally ignored so they cannot become
        // an account-existence oracle.
        await _api.post<Map<String, dynamic>>(
          '/api/forgot-password',
          data: {'email': email.trim()},
        );
      }
    } on DioException {
      // Includes badResponse (500/503), timeouts, and connection errors.
    } catch (_) {
      // Malformed payloads / unexpected local failures — never leak.
    }
  }

  /// Step 3 of web-parity reset: exchange email + 6-digit code for a new password.
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    if (AppConfig.usesLaravelAuth) {
      throw AuthException(
        'Password reset is not available in this testing version. Please contact MKG Tax Consultants for assistance.',
      );
    }
    final res = await _api.post<Map<String, dynamic>>(
      '/api/reset-password',
      data: {
        'email': email.trim(),
        'code': code.trim(),
        'newPassword': newPassword,
      },
    );
    if ((res.statusCode ?? 500) >= 400) {
      throw AuthException(_authErrorMessage(res.statusCode, 'That code is invalid or has expired. Please request a new one.'));
    }
  }

  Future<void> logout() async {
    try {
      if (AppConfig.usesLaravelAuth) {
        await _api.post('/auth/logout');
      } else {
        await _api.post('/api/logout');
      }
    } on DioException {
      // still clear local session
    }
    await _persistToken(null);
    await _api.clearSession();
  }

  Future<Map<String, dynamic>?> currentTaxReturn() async {
    if (AppConfig.usesLaravelAuth) return null;
    final res = await _api.get<dynamic>('/api/tax-returns/current');
    if (res.statusCode != 200 || res.data == null) return null;
    if (res.data is Map<String, dynamic>) return res.data as Map<String, dynamic>;
    if (res.data is Map) return Map<String, dynamic>.from(res.data as Map);
    return null;
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> body) async {
    if (AppConfig.usesLaravelAuth) {
      throw AuthException(
        'Profile updates are not available in this testing version. Please contact MKG Tax Consultants for assistance.',
      );
    }
    final res = await _api.put<Map<String, dynamic>>('/api/user/profile', data: body);
    if (res.statusCode == 200) return Map<String, dynamic>.from(res.data ?? {});
    throw AuthException(_authErrorMessage(res.statusCode, 'Profile update failed. Please try again.'));
  }

  /// Sanctum: GET + PATCH `/api/v1/profile` (versioned sync with portal bridge).
  /// Cookie portal: POST `/api/user/kyc-submit` (legacy).
  Future<PortalUser> submitProfileForReview({
    required String phone,
    required String address,
    String apartment = '',
    required String city,
    required String state,
    required String zipCode,
    String firstName = '',
    String lastName = '',
  }) async {
    if (AppConfig.usesLaravelAuth) {
      return _submitLaravelProfile(
        phone: phone,
        address: address,
        apartment: apartment,
        city: city,
        state: state,
        zipCode: zipCode,
        firstName: firstName,
        lastName: lastName,
      );
    }
    final res = await _api.post<dynamic>(
      '/api/user/kyc-submit',
      data: {
        'role': 'client',
        'phone': phone,
        'address': address,
        'city': city,
        'state': state,
        'zipCode': zipCode,
        if (firstName.trim().isNotEmpty) 'firstName': firstName.trim(),
        if (lastName.trim().isNotEmpty) 'lastName': lastName.trim(),
      },
    );
    if ((res.statusCode ?? 500) >= 400 || res.data is! Map) {
      throw AuthException(
        _authErrorMessage(res.statusCode, 'Unable to submit your profile. Please try again.'),
      );
    }
    return PortalUser.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<PortalUser> _submitLaravelProfile({
    required String phone,
    required String address,
    required String apartment,
    required String city,
    required String state,
    required String zipCode,
    String firstName = '',
    String lastName = '',
  }) async {
    final laravel = _laravel;
    if (laravel == null || laravel.bearerToken == null) {
      throw AuthException(ApiErrorMapper.loginSessionExpiredMessage);
    }

    Future<Map<String, dynamic>> loadProfile() async {
      final res = await laravel.get<Map<String, dynamic>>('/api/v1/profile');
      if ((res.statusCode ?? 500) >= 400) {
        throw AuthException(
          _authErrorMessage(res.statusCode, 'Unable to load your profile. Please try again.'),
        );
      }
      final data = res.data?['data'];
      if (data is Map) return Map<String, dynamic>.from(data);
      if (res.data is Map) return Map<String, dynamic>.from(res.data!);
      throw AuthException('Unable to load your profile. Please try again.');
    }

    var current = await loadProfile();
    var version = (current['version'] as num?)?.toInt();
    if (version == null || version < 1) {
      throw AuthException('Unable to update your profile right now. Please try again.');
    }

    final preferred = [firstName.trim(), lastName.trim()].where((s) => s.isNotEmpty).join(' ');
    final payload = <String, dynamic>{
      'version': version,
      'phone': phone.trim().isEmpty ? null : phone.trim(),
      if (firstName.trim().isNotEmpty) 'first_name': firstName.trim(),
      if (lastName.trim().isNotEmpty) 'last_name': lastName.trim(),
      if (preferred.isNotEmpty && firstName.trim().isEmpty) 'preferred_name': preferred,
      'mailing_address': {
        'line1': address.trim(),
        'line2': apartment.trim().isEmpty ? null : apartment.trim(),
        'city': city.trim(),
        'state': state.trim().toUpperCase(),
        'postal_code': zipCode.trim(),
        'country': 'US',
      },
    };

    for (var attempt = 0; attempt < 2; attempt++) {
      payload['version'] = version;
      final res = await laravel.patch<Map<String, dynamic>>(
        '/api/v1/profile',
        data: payload,
      );
      if (res.statusCode == 200) {
        final data = res.data?['data'];
        final map = data is Map
            ? Map<String, dynamic>.from(data)
            : Map<String, dynamic>.from(res.data ?? {});
        return PortalUser.fromLaravelProfile(map, fallback: await currentUser());
      }
      if (res.statusCode == 409) {
        // Optimistic concurrency — reload version and retry once.
        final raw = res.data;
        final conflictVersion = raw == null
            ? null
            : (raw['currentVersion'] as num?)?.toInt();
        if (conflictVersion != null && conflictVersion > 0) {
          version = conflictVersion;
        } else {
          current = await loadProfile();
          version = (current['version'] as num?)?.toInt() ?? version;
        }
        continue;
      }
      throw AuthException(
        _authErrorMessage(res.statusCode, 'Unable to submit your profile. Please try again.'),
      );
    }
    throw AuthException(
      'This information changed on another device or in the client portal. Please review and try again.',
    );
  }

  /// Portal-hosted Stripe Identity session (no secrets in the app).
  Future<Map<String, dynamic>> beginIdentityVerification() async {
    if (!AppConfig.usesLaravelAuth) {
      throw AuthException('Identity verification requires the Laravel mobile API.');
    }
    final laravel = _laravel;
    if (laravel == null || laravel.bearerToken == null) {
      throw AuthException(ApiErrorMapper.loginSessionExpiredMessage);
    }
    final res = await laravel.post<Map<String, dynamic>>(
      '/api/v1/identity-verification/session',
      data: const {},
    );
    if ((res.statusCode ?? 500) >= 400) {
      throw AuthException(
        _authErrorMessage(res.statusCode, 'Unable to start identity verification. Please try again.'),
      );
    }
    final data = res.data?['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    if (res.data is Map) return Map<String, dynamic>.from(res.data!);
    throw AuthException('Unable to start identity verification. Please try again.');
  }

  Future<PortalUser> refreshUser() async {
    final user = await currentUser();
    if (user == null) throw AuthException('Not authenticated');
    return user;
  }
}

/// Lets [GoRouter] rebuild redirects when auth state changes.
class AuthRouterRefresh extends ChangeNotifier {
  void ping() => notifyListeners();
}

final authRouterRefreshProvider = Provider<AuthRouterRefresh>((ref) {
  return AuthRouterRefresh();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(apiClientProvider),
    laravel: ref.watch(laravelApiClientProvider),
  );
});

class AuthState {
  const AuthState({this.user, this.loading = false, this.error});
  final PortalUser? user;
  final bool loading;
  final String? error;

  bool get isAuthenticated => user != null;

  AuthState copyWith({PortalUser? user, bool? loading, String? error, bool clearUser = false}) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      loading: loading ?? this.loading,
      error: error,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState(loading: false);

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  void _pingRouter() {
    ref.read(authRouterRefreshProvider).ping();
  }

  Future<void> restoreSession() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final user = await _repo.currentUser();
      state = AuthState(user: user, loading: false);
    } catch (_) {
      state = const AuthState(loading: false);
    }
    _pingRouter();
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final user = await _repo.login(email: email, password: password);
      state = AuthState(user: user, loading: false);
      _pingRouter();
      return true;
    } on AuthException catch (e) {
      state = AuthState(loading: false, error: e.message);
      _pingRouter();
      return false;
    } catch (e) {
      state = AuthState(loading: false, error: ApiErrorMapper.mapLogin(e));
      _pingRouter();
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
    String? referralCode,
  }) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final user = await _repo.register(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        referralCode: referralCode,
      );
      state = AuthState(user: user, loading: false);
      _pingRouter();
      return true;
    } on AuthException catch (e) {
      state = AuthState(loading: false, error: e.message);
      _pingRouter();
      return false;
    } catch (e) {
      state = AuthState(loading: false, error: ApiErrorMapper.map(e));
      _pingRouter();
      return false;
    }
  }

  Future<void> setUser(PortalUser user) async {
    state = AuthState(user: user, loading: false);
    _pingRouter();
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState();
    _pingRouter();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
