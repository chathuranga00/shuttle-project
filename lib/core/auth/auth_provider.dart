import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';

class AuthUser {
  final int id;
  final String email;
  final String role;

  const AuthUser({required this.id, required this.email, required this.role});

  bool get isAdmin => role == 'ADMIN';
}

class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final AuthUser? user;
  final String? token;
  final String? errorMessage;

  const AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.user,
    this.token,
    this.errorMessage,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    AuthUser? user,
    String? token,
    String? errorMessage,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      token: token ?? this.token,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _apiClient;

  AuthNotifier(this._apiClient) : super(const AuthState(isLoading: true)) {
    checkInitialAuth();
  }

  Future<void> checkInitialAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('admin_access_token');
      if (token != null && token.isNotEmpty) {
        final user = _decodeUserFromToken(token);
        if (user != null && user.isAdmin) {
          _apiClient.setToken(token);
          state = AuthState(
            isLoading: false,
            isAuthenticated: true,
            user: user,
            token: token,
          );
          return;
        }
      }
    } catch (_) {
      // Ignore parsing errors on stored token
    }
    state = const AuthState(isLoading: false, isAuthenticated: false);
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _apiClient.post(
        ApiEndpoints.login,
        data: {'email': email.trim(), 'password': password},
      );

      final data = response.data as Map<String, dynamic>;
      final accessToken = data['accessToken'] as String?;

      if (accessToken == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Login failed: Invalid token response',
        );
        return false;
      }

      final user = _decodeUserFromToken(accessToken);
      if (user == null || !user.isAdmin) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Access denied: Admin credentials required',
        );
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('admin_access_token', accessToken);
      _apiClient.setToken(accessToken);

      state = AuthState(
        isLoading: false,
        isAuthenticated: true,
        user: user,
        token: accessToken,
      );
      return true;
    } on DioException catch (e) {
      String message = 'Login failed';
      if (e.response?.data != null && e.response?.data is Map) {
        final resData = e.response!.data as Map;
        message = resData['message']?.toString() ?? message;
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError) {
        message = 'Cannot connect to backend server';
      }
      state = state.copyWith(isLoading: false, errorMessage: message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('admin_access_token');
    _apiClient.setToken(null);
    state = const AuthState(isAuthenticated: false);
  }

  AuthUser? _decodeUserFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(payload));
      final map = jsonDecode(decoded) as Map<String, dynamic>;
      final id = (map['userId'] as num?)?.toInt() ?? 0;
      final email = map['sub'] as String? ?? '';
      final role = map['role'] as String? ?? '';
      return AuthUser(id: id, email: email, role: role);
    } catch (_) {
      return null;
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AuthNotifier(apiClient);
});
