import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

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
  });

  final dynamic id;
  final String email;
  final String firstName;
  final String lastName;
  final String? phone;
  final String? role;
  final String? kycStatus;
  final String? approvalStatus;

  String get displayName {
    final name = '$firstName $lastName'.trim();
    return name.isEmpty ? email : name;
  }

  factory PortalUser.fromJson(Map<String, dynamic> json) {
    return PortalUser(
      id: json['id'],
      email: (json['email'] ?? '').toString(),
      firstName: (json['firstName'] ?? '').toString(),
      lastName: (json['lastName'] ?? '').toString(),
      phone: json['phone']?.toString(),
      role: json['role']?.toString(),
      kycStatus: json['kycStatus']?.toString(),
      approvalStatus: json['approvalStatus']?.toString(),
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

class AuthRepository {
  AuthRepository(this._api);
  final ApiClient _api;

  Future<PortalUser?> currentUser() async {
    final res = await _api.get<Map<String, dynamic>>('/api/auth/user');
    if (res.statusCode == 401 || res.data == null) return null;
    if (res.statusCode != 200) return null;
    return PortalUser.fromJson(Map<String, dynamic>.from(res.data!));
  }

  Future<PortalUser> login({
    required String email,
    required String password,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/api/login',
      data: {'email': email.trim(), 'password': password},
    );
    final data = res.data ?? {};
    if (res.statusCode == 200) {
      if (data['requires2FA'] == true || data['totpPending'] == true) {
        throw AuthException('Two-factor authentication required. Use the web portal or complete 2FA next.', requires2FA: true);
      }
      if (data['requiresPasswordSetup'] == true) {
        throw AuthException('Password setup required. Complete it on financemkgtax.com first.');
      }
      return PortalUser.fromJson(Map<String, dynamic>.from(data));
    }
    final msg = (data['message'] ?? data['error'] ?? 'Login failed (${res.statusCode})').toString();
    throw AuthException(msg);
  }

  Future<PortalUser> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
    String? referralCode,
  }) async {
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
    final msg = (data['message'] ?? data['error'] ?? 'Registration failed (${res.statusCode})').toString();
    throw AuthException(msg);
  }

  Future<void> logout() async {
    try {
      await _api.post('/api/logout');
    } on DioException {
      // still clear local cookies
    }
    await _api.clearSession();
  }

  Future<Map<String, dynamic>?> currentTaxReturn() async {
    final res = await _api.get<dynamic>('/api/tax-returns/current');
    if (res.statusCode != 200 || res.data == null) return null;
    if (res.data is Map<String, dynamic>) return res.data as Map<String, dynamic>;
    if (res.data is Map) return Map<String, dynamic>.from(res.data as Map);
    return null;
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> body) async {
    final res = await _api.put<Map<String, dynamic>>('/api/user/profile', data: body);
    final data = res.data ?? {};
    if (res.statusCode == 200) return Map<String, dynamic>.from(data);
    throw AuthException((data['message'] ?? 'Profile update failed').toString());
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
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

  Future<void> restoreSession() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final user = await _repo.currentUser();
      state = AuthState(user: user, loading: false);
    } catch (_) {
      state = const AuthState(loading: false);
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final user = await _repo.login(email: email, password: password);
      state = AuthState(user: user, loading: false);
      return true;
    } on AuthException catch (e) {
      state = AuthState(loading: false, error: e.message);
      return false;
    } catch (e) {
      state = AuthState(loading: false, error: e.toString());
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
      return true;
    } on AuthException catch (e) {
      state = AuthState(loading: false, error: e.message);
      return false;
    } catch (e) {
      state = AuthState(loading: false, error: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
