import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Keys ──────────────────────────────────────────────────────────────────────
class _Keys {
  static const accessToken = 'access_token';
  static const refreshToken = 'refresh_token';
  static const userRole = 'user_role';
  static const userId = 'user_id';
}

// ── Service ───────────────────────────────────────────────────────────────────
class SecureStorageService {
  SecureStorageService(this._storage);

  final FlutterSecureStorage _storage;

  // Access token
  Future<void> saveAccessToken(String token) =>
      _storage.write(key: _Keys.accessToken, value: token);
  Future<String?> getAccessToken() =>
      _storage.read(key: _Keys.accessToken);

  // Refresh token
  Future<void> saveRefreshToken(String token) =>
      _storage.write(key: _Keys.refreshToken, value: token);
  Future<String?> getRefreshToken() =>
      _storage.read(key: _Keys.refreshToken);

  // User role (STUDENT | DRIVER | ADMIN)
  Future<void> saveUserRole(String role) =>
      _storage.write(key: _Keys.userRole, value: role);
  Future<String?> getUserRole() => _storage.read(key: _Keys.userRole);

  // User ID
  Future<void> saveUserId(String id) =>
      _storage.write(key: _Keys.userId, value: id);
  Future<String?> getUserId() => _storage.read(key: _Keys.userId);

  /// Save all auth data atomically.
  Future<void> saveAuthData({
    required String accessToken,
    required String refreshToken,
    required String role,
  }) async {
    await Future.wait([
      saveAccessToken(accessToken),
      saveRefreshToken(refreshToken),
      saveUserRole(role),
    ]);
  }

  /// Clear all stored auth data (logout).
  Future<void> clearAll() => _storage.deleteAll();

  /// Quick check: is a token present?
  Future<bool> hasAccessToken() async =>
      (await getAccessToken()) != null;
}

// ── Provider ─────────────────────────────────────────────────────────────────
final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
  return SecureStorageService(storage);
});
