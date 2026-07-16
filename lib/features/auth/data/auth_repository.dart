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

/// Uniform message for the forgot-password flow, deliberately identical
/// regardless of status code or response body content: this endpoint must
/// not let a client observe whether a given email is a registered account.
const String _passwordResetRequestedMessage =
    'If an account exists for that email, a reset code has been sent.';

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
          throw AuthException('Login succeeded but no Sanctum token was returned.');
        }
        await _persistToken(token);
        final userMap = data['user'] is Map
            ? Map<String, dynamic>.from(data['user'] as Map)
            : Map<String, dynamic>.from(data);
        // Normalize Sanctum claims shape for PortalUser.
        if (userMap['email'] == null && userMap['external_user_id'] != null) {
          userMap['email'] = email.trim();
        }
        if (userMap['id'] == null) {
          userMap['id'] = userMap['external_user_id'];
        }
        return PortalUser.fromJson(userMap);
      }
      throw AuthException(_authErrorMessage(res.statusCode, 'Login failed. Please try again.'));
    }

    final res = await _api.post<Map<String, dynamic>>(
      '/api/login',
      data: {'email': email.trim(), 'password': password},
    );
    final data = res.data ?? {};
    if (res.statusCode == 200) {
      if (data['requires2FA'] == true || data['totpPending'] == true) {
        throw AuthException(
          'Two-factor authentication required. Use the web portal or complete 2FA next.',
          requires2FA: true,
        );
      }
      if (data['requiresPasswordSetup'] == true) {
        throw AuthException('Password setup required. Complete it on ${AppConfig.webRoot} first.');
      }
      return PortalUser.fromJson(Map<String, dynamic>.from(data));
    }
    throw AuthException(_authErrorMessage(res.statusCode, 'Login failed. Please try again.'));
  }

  Future<PortalUser> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
    String? referralCode,
  }) async {
    if (AppConfig.usesLaravelAuth) {
      throw AuthException(
        'Client registration via Laravel Sanctum is not enabled yet. '
        'Register on ${AppConfig.webRoot} or use a transitional portal build.',
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
      return PortalUser.fromJson(Map<String, dynamic>.from(data));
    }
    throw AuthException(_authErrorMessage(res.statusCode, 'Registration failed. Please try again.'));
  }

  /// Step 1 of web-parity reset: send 6-digit code via email/SMS.
  Future<void> requestPasswordReset(String email) async {
    if (AppConfig.usesLaravelAuth) {
      throw AuthException('Password reset via Laravel API is not enabled yet. Use ${AppConfig.webRoot}.');
    }
    final res = await _api.post<Map<String, dynamic>>(
      '/api/forgot-password',
      data: {'email': email.trim()},
    );
    if ((res.statusCode ?? 500) >= 400) {
      // Deliberately uniform regardless of status code or response body —
      // this step must never let a caller distinguish "no such account"
      // from any other outcome. See _passwordResetRequestedMessage.
      throw AuthException(_passwordResetRequestedMessage);
    }
  }

  /// Step 3 of web-parity reset: exchange email + 6-digit code for a new password.
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    if (AppConfig.usesLaravelAuth) {
      throw AuthException('Password reset via Laravel API is not enabled yet. Use ${AppConfig.webRoot}.');
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
      throw AuthException('Profile update via Laravel API is not enabled yet.');
    }
    final res = await _api.put<Map<String, dynamic>>('/api/user/profile', data: body);
    if (res.statusCode == 200) return Map<String, dynamic>.from(res.data ?? {});
    throw AuthException(_authErrorMessage(res.statusCode, 'Profile update failed. Please try again.'));
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
      state = AuthState(loading: false, error: ApiErrorMapper.map(e));
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
