import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../core/network/laravel_api_client.dart';
import '../../../core/sync/sync_cursor_store.dart';
import '../../../core/sync/sync_models.dart';
import '../../../core/sync/sync_providers.dart';

/// Result of [AuthRepository.register]. Sanctum signups require email
/// verification before login; cookie/portal register may return a session user.
class RegistrationResult {
  const RegistrationResult({
    required this.verificationRequired,
    required this.message,
    this.user,
    this.created = false,
  });

  final bool created;
  final bool verificationRequired;
  final String message;
  final PortalUser? user;
}

String _uuidV4() {
  final r = Random.secure();
  final bytes = List<int>.generate(16, (_) => r.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}

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
    return PortalUser.fromJson({
      ...profile,
      'id': profile['external_user_id'] ?? fallback?.id,
      'firstName': fallback?.firstName,
      'lastName': fallback?.lastName,
      'name': profile['name'] ?? profile['preferred_name'] ?? fallback?.displayName,
      'approval_status': approval,
      'kyc_status': kyc,
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
  AuthRepository(
    this._api, {
    LaravelApiClient? laravel,
    Dio? portalClient,
  })  : _laravel = laravel,
        _portalClient = portalClient;

  final ApiClient _api;
  final LaravelApiClient? _laravel;
  /// Optional override for portal-origin calls (password-reset confirm).
  /// Production uses [AppConfig.portalRoot] (`https://mkgtaxconsultants.com`).
  final Dio? _portalClient;

  /// Test-only override for [AppConfig.usesLaravelAuth] (compile-time define).
  @visibleForTesting
  static bool Function()? debugUsesLaravelAuth;

  bool get _usesLaravelAuth =>
      debugUsesLaravelAuth?.call() ?? AppConfig.usesLaravelAuth;

  static const _tokenKey = LaravelApiClient.sanctumTokenStorageKey;
  static const _storage = FlutterSecureStorage();

  Dio _portalDio() {
    return _portalClient ??
        Dio(
          BaseOptions(
            baseUrl: AppConfig.portalRoot,
            connectTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 30),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            // Mirror ApiClient: surface 5xx as DioException.badResponse.
            validateStatus: (code) => code != null && code < 500,
          ),
        );
  }

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
    if (_usesLaravelAuth) {
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

  /// Returns true when a 401 body is an intentional MFA challenge (not bad password).
  static bool isMfaRequiredBody(Map<String, dynamic> data) {
    if (data['error']?.toString() == 'mfa_required') return true;
    final verification = data['verification'];
    if (verification is Map && verification['mfa_required'] == true) return true;
    return false;
  }

  Future<PortalUser> login({
    required String email,
    required String password,
    String? otp,
  }) async {
    if (_usesLaravelAuth) {
      final payload = <String, dynamic>{
        'identifier': email.trim(),
        'password': password,
        'device_name': 'mkg-tax-mobile',
      };
      final otpTrimmed = otp?.trim();
      if (otpTrimmed != null && otpTrimmed.isNotEmpty) {
        payload['otp'] = otpTrimmed;
      }
      final res = await _api.post<Map<String, dynamic>>(
        '/auth/login',
        data: payload,
      );
      final data = Map<String, dynamic>.from(res.data ?? {});
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
      if (isMfaRequiredBody(data)) {
        // Password was accepted; portal emailed a login OTP (same as web).
        final challengedAgain = otpTrimmed != null && otpTrimmed.isNotEmpty;
        throw AuthException(
          challengedAgain
              ? ApiErrorMapper.loginOtpInvalidMessage
              : ApiErrorMapper.loginOtpRequiredMessage,
          requiresOtp: true,
        );
      }
      throw AuthException(_loginErrorMessage(res.statusCode));
    }

    final res = await _api.post<Map<String, dynamic>>(
      '/api/login',
      data: {
        'email': email.trim(),
        'password': password,
        if (otp != null && otp.trim().isNotEmpty) 'otp': otp.trim(),
      },
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
    if (isMfaRequiredBody(Map<String, dynamic>.from(data))) {
      throw AuthException(
        ApiErrorMapper.loginOtpRequiredMessage,
        requiresOtp: true,
      );
    }
    throw AuthException(_loginErrorMessage(res.statusCode));
  }

  /// Client-facing copy when online registration is disabled for this build.
  static const registrationUnavailableMessage =
      'Online account registration is not available in this testing version. Please contact MKG Tax Consultants for assistance.';

  static const registrationVerificationMessage =
      'Account created. Enter the verification code sent to your email, then sign in.';

  Future<RegistrationResult> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
    String? referralCode,
  }) async {
    if (_usesLaravelAuth) {
      final res = await _api.post<Map<String, dynamic>>(
        '/auth/register',
        data: {
          'email': email.trim(),
          'phone': phone.trim(),
          'password': password,
          'password_confirmation': password,
          'first_name': firstName.trim(),
          'last_name': lastName.trim(),
          'consents': {
            'terms_version': '1.0',
            'privacy_version': '1.0',
            'electronic_communications': true,
          },
          'idempotency_key': _uuidV4(),
        },
      );
      final data = Map<String, dynamic>.from(res.data ?? {});
      if (res.statusCode == 503) {
        final err = data['error'];
        final msg = err is Map ? err['message']?.toString() : null;
        throw AuthException(msg ?? registrationUnavailableMessage);
      }
      if ((res.statusCode ?? 500) >= 400) {
        throw AuthException(
          _authErrorMessage(res.statusCode, 'Registration failed. Please try again.'),
        );
      }
      return RegistrationResult(
        created: data['created'] == true,
        verificationRequired: data['verification_required'] != false,
        message: (data['message'] as String?)?.trim().isNotEmpty == true
            ? data['message'] as String
            : registrationVerificationMessage,
      );
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
      return RegistrationResult(
        created: true,
        verificationRequired: false,
        message: 'Account created.',
        user: PortalUser.fromJson(Map<String, dynamic>.from(data)),
      );
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
      if (_usesLaravelAuth) {
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
  ///
  /// Sanctum builds confirm via Laravel façade
  /// (`POST /auth/password-reset/confirm` → portal S2S). Cookie-portal builds
  /// keep using `_api` on the portal base URL.
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      final Response<Map<String, dynamic>> res;
      if (_usesLaravelAuth) {
        res = await _api.post<Map<String, dynamic>>(
          '/auth/password-reset/confirm',
          data: {
            'email': email.trim(),
            'code': code.trim(),
            'new_password': newPassword,
          },
        );
      } else {
        res = await _api.post<Map<String, dynamic>>(
          '/api/reset-password',
          data: {
            'email': email.trim(),
            'code': code.trim(),
            'newPassword': newPassword,
          },
        );
      }
      if ((res.statusCode ?? 500) >= 400) {
        throw AuthException(
          _authErrorMessage(
            res.statusCode,
            'That code is invalid or has expired. Please request a new one.',
          ),
        );
      }
    } on AuthException {
      rethrow;
    } on DioException catch (e) {
      throw AuthException(
        _authErrorMessage(
          e.response?.statusCode,
          'That code is invalid or has expired. Please request a new one.',
        ),
      );
    }
  }

  /// Pre-login email verification for Sanctum signups (email + code).
  Future<void> confirmEmailVerification({
    required String email,
    required String code,
  }) async {
    if (!_usesLaravelAuth) {
      throw AuthException('Email verification is not available for this build.');
    }
    try {
      final res = await _api.post<Map<String, dynamic>>(
        '/auth/verify-email',
        data: {
          'email': email.trim(),
          'code': code.trim(),
          'channel': 'email',
        },
      );
      final data = Map<String, dynamic>.from(res.data ?? {});
      if ((res.statusCode ?? 500) >= 500) {
        throw AuthException('Verification service unavailable. Please try again.');
      }
      if (data['verified'] != true) {
        throw AuthException(
          (data['message'] as String?)?.trim().isNotEmpty == true
              ? data['message'] as String
              : 'That code is invalid or has expired. Please try again.',
        );
      }
    } on AuthException {
      rethrow;
    } on DioException catch (e) {
      throw AuthException(
        _authErrorMessage(
          e.response?.statusCode,
          'That code is invalid or has expired. Please try again.',
        ),
      );
    }
  }

  Future<void> logout() async {
    try {
      if (_usesLaravelAuth) {
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
    if (_usesLaravelAuth) return null;
    final res = await _api.get<dynamic>('/api/tax-returns/current');
    if (res.statusCode != 200 || res.data == null) return null;
    if (res.data is Map<String, dynamic>) return res.data as Map<String, dynamic>;
    if (res.data is Map) return Map<String, dynamic>.from(res.data as Map);
    return null;
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> body) async {
    if (_usesLaravelAuth) {
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
  }) async {
    if (_usesLaravelAuth) {
      return _submitLaravelProfile(
        phone: phone,
        address: address,
        apartment: apartment,
        city: city,
        state: state,
        zipCode: zipCode,
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
  }) async {
    final laravel = _laravel;
    // Rehydrate bearer from secure storage — provider rebuilds can drop the
    // in-memory token while the session is still valid (looked like a logout).
    final token = await _readToken();
    if (laravel == null || token == null || token.isEmpty) {
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
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        if (map['error'] != null) {
          throw AuthException('Unable to load your profile. Please try again.');
        }
        return map;
      }
      if (res.data is Map) return Map<String, dynamic>.from(res.data!);
      throw AuthException('Unable to load your profile. Please try again.');
    }

    var current = await loadProfile();
    var version = (current['version'] as num?)?.toInt();
    if (version == null || version < 1) {
      throw AuthException('Unable to update your profile right now. Please try again.');
    }

    // Omit nulls — Laravel ConvertEmptyStringsToNull + portal Zod .optional()
    // previously rejected JSON null for line2/phone and returned error-shaped 200s.
    final mailing = <String, dynamic>{
      'line1': address.trim(),
      'city': city.trim(),
      'state': state.trim().toUpperCase(),
      'postal_code': zipCode.trim(),
      'country': 'US',
    };
    final apt = apartment.trim();
    if (apt.isNotEmpty) mailing['line2'] = apt;

    final payload = <String, dynamic>{
      'version': version,
      'mailing_address': mailing,
    };
    final phoneTrimmed = phone.trim();
    if (phoneTrimmed.isNotEmpty) payload['phone'] = phoneTrimmed;

    final sessionFallback = await currentUser();

    for (var attempt = 0; attempt < 2; attempt++) {
      payload['version'] = version;
      final res = await laravel.patch<Map<String, dynamic>>(
        '/api/v1/profile',
        data: payload,
      );
      final data = res.data?['data'];
      final map = data is Map
          ? Map<String, dynamic>.from(data)
          : (res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{});

      if (res.statusCode == 200 && map['error'] == null && map['external_user_id'] != null) {
        return PortalUser.fromLaravelProfile(map, fallback: sessionFallback);
      }
      if (res.statusCode == 409) {
        if (attempt > 0) {
          throw SyncConflictException(
            SyncConflict.fromResponse(
              res,
              entityType: 'profile',
              entityId: '${current['external_user_id'] ?? current['id'] ?? 'profile'}',
              localValues: Map<String, dynamic>.from(payload),
            ),
          );
        }
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

  /// Enrich Sanctum session claims with GET /api/v1/profile (address / KYC).
  Future<PortalUser> hydrateLaravelProfile(PortalUser fallback) async {
    final laravel = _laravel;
    final token = await _readToken();
    if (laravel == null || token == null || token.isEmpty) return fallback;
    try {
      final res = await laravel.get<Map<String, dynamic>>('/api/v1/profile');
      if ((res.statusCode ?? 500) >= 400) return fallback;
      final data = res.data?['data'];
      if (data is! Map) return fallback;
      final map = Map<String, dynamic>.from(data);
      if (map['error'] != null) return fallback;
      return PortalUser.fromLaravelProfile(map, fallback: fallback);
    } catch (_) {
      return fallback;
    }
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
  const AuthState({
    this.user,
    this.loading = false,
    this.error,
    this.requiresOtp = false,
  });
  final PortalUser? user;
  final bool loading;
  final String? error;
  /// Password was accepted; UI should collect the email OTP and resubmit.
  final bool requiresOtp;

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    PortalUser? user,
    bool? loading,
    String? error,
    bool? requiresOtp,
    bool clearUser = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      loading: loading ?? this.loading,
      error: error,
      requiresOtp: requiresOtp ?? this.requiresOtp,
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
      var user = await _repo.currentUser();
      if (user != null && AppConfig.usesLaravelAuth) {
        user = await _repo.hydrateLaravelProfile(user);
      }
      state = AuthState(user: user, loading: false);
      _setSyncAccount(user);
      if (user != null) {
        unawaited(
          ref.read(syncCoordinatorProvider).pull(reason: 'restore').catchError((_) => SyncPullResult.empty),
        );
      }
    } catch (_) {
      state = const AuthState(loading: false);
      _setSyncAccount(null);
    }
    _pingRouter();
  }

  /// Returns true on success. When [AuthState.requiresOtp] is set, password
  /// was accepted and the UI must collect the emailed OTP then call again
  /// with [otp] (same shared password as the web portal).
  Future<bool> login(String email, String password, {String? otp}) async {
    state = state.copyWith(loading: true, error: null);
    try {
      var user = await _repo.login(email: email, password: password, otp: otp);
      if (AppConfig.usesLaravelAuth) {
        user = await _repo.hydrateLaravelProfile(user);
      }
      state = AuthState(user: user, loading: false);
      _setSyncAccount(user);
      unawaited(
        ref.read(syncCoordinatorProvider).pull(reason: 'login').catchError((_) => SyncPullResult.empty),
      );
      _pingRouter();
      return true;
    } on AuthException catch (e) {
      state = AuthState(
        loading: false,
        error: e.message,
        requiresOtp: e.requiresOtp || e.requires2FA,
      );
      _pingRouter();
      return false;
    } catch (e) {
      state = AuthState(loading: false, error: ApiErrorMapper.mapLogin(e));
      _pingRouter();
      return false;
    }
  }

  /// Returns a [RegistrationResult] on success, or null on failure (see [AuthState.error]).
  Future<RegistrationResult?> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
    String? referralCode,
  }) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final result = await _repo.register(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        referralCode: referralCode,
      );
      if (result.user != null) {
        state = AuthState(user: result.user, loading: false);
      } else {
        state = const AuthState(loading: false);
      }
      _pingRouter();
      return result;
    } on AuthException catch (e) {
      state = AuthState(loading: false, error: e.message);
      _pingRouter();
      return null;
    } catch (e) {
      state = AuthState(loading: false, error: ApiErrorMapper.map(e));
      _pingRouter();
      return null;
    }
  }

  Future<void> setUser(PortalUser user) async {
    state = AuthState(user: user, loading: false);
    _setSyncAccount(user);
    _pingRouter();
  }

  Future<void> logout() async {
    final accountKey = ref.read(activeSyncAccountKeyProvider) ??
        SyncCursorStore.accountKeyFor(
          externalUserId: state.user?.id,
          email: state.user?.email,
        );
    await _repo.logout();
    if (accountKey != null) {
      await ref.read(syncCoordinatorProvider).clearAccount(accountKey: accountKey);
    }
    ref.read(activeSyncAccountKeyProvider.notifier).state = null;
    ref.invalidate(syncCachedSummariesProvider);
    ref.invalidate(syncCoordinatorProvider);
    state = const AuthState();
    _pingRouter();
  }

  void _setSyncAccount(PortalUser? user) {
    ref.read(activeSyncAccountKeyProvider.notifier).state = SyncCursorStore.accountKeyFor(
      externalUserId: user?.id,
      email: user?.email,
    );
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
