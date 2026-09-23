import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../data/auth_repository.dart';
import '../../data/models/login_request.dart';
import '../../data/models/register_request.dart';

// ── Auth state ────────────────────────────────────────────────────────────────
enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.role,
    this.errorMessage,
    this.isLoading = false,
  });

  final AuthStatus status;
  final String? role;       // 'STUDENT' | 'DRIVER' | 'ADMIN'
  final String? errorMessage;
  final bool isLoading;

  AuthState copyWith({
    AuthStatus? status,
    String? role,
    String? errorMessage,
    bool? isLoading,
    bool clearError = false,
  }) =>
      AuthState(
        status: status ?? this.status,
        role: role ?? this.role,
        errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
        isLoading: isLoading ?? this.isLoading,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repository, this._storage) : super(const AuthState());

  final AuthRepository _repository;
  final SecureStorageService _storage;

  /// Called on app start from the Splash screen.
  Future<void> checkAuthStatus() async {
    final token = await _storage.getAccessToken();
    final role = await _storage.getUserRole();
    if (token != null && role != null) {
      state = state.copyWith(
        status: AuthStatus.authenticated,
        role: role,
        isLoading: false,
      );
    } else {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        isLoading: false,
      );
    }
  }

  Future<void> login({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repository.login(LoginRequest(email: email, password: password));
      final role = await _storage.getUserRole() ?? 'STUDENT';
      state = state.copyWith(
        status: AuthStatus.authenticated,
        role: role,
        isLoading: false,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ApiException.friendlyMessage(e),
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Something went wrong. Please try again.',
      );
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String studentId,
    required String faculty,
    required int year,
    String? phone,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repository.register(RegisterRequest(
        name: name,
        email: email,
        password: password,
        studentId: studentId,
        faculty: faculty,
        year: year,
        phone: phone,
      ));
      final role = await _storage.getUserRole() ?? 'STUDENT';
      state = state.copyWith(
        status: AuthStatus.authenticated,
        role: role,
        isLoading: false,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ApiException.friendlyMessage(e),
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Something went wrong. Please try again.',
      );
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void clearError() => state = state.copyWith(clearError: true);
}

// ── Provider ──────────────────────────────────────────────────────────────────
final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.watch(authRepositoryProvider),
    ref.watch(secureStorageServiceProvider),
  );
});
