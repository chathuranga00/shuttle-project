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

  Future<String?> _safeRead(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      try {
        await _storage.delete(key: key);
      } catch (_) {}
      return null;
    }
  }

  Future<void> _safeWrite(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {
      try {
        await _storage.delete(key: key);
        await _storage.write(key: key, value: value);
      } catch (_) {}
    }
  }

  // Access token
  Future<void> saveAccessToken(String token) =>
      _safeWrite(_Keys.accessToken, token);
  Future<String?> getAccessToken() =>
      _safeRead(_Keys.accessToken);

  // Refresh token
  Future<void> saveRefreshToken(String token) =>
      _safeWrite(_Keys.refreshToken, token);
  Future<String?> getRefreshToken() =>
      _safeRead(_Keys.refreshToken);

  // User role (STUDENT | DRIVER | ADMIN)
  Future<void> saveUserRole(String role) =>
      _safeWrite(_Keys.userRole, role);
  Future<String?> getUserRole() => _safeRead(_Keys.userRole);

  // User ID
  Future<void> saveUserId(String id) =>
      _safeWrite(_Keys.userId, id);
  Future<String?> getUserId() => _safeRead(_Keys.userId);

  /// Save all auth data atomically and sequentially to prevent WebCrypto key race conditions.
  Future<void> saveAuthData({
    required String accessToken,
    required String refreshToken,
    required String role,
  }) async {
    await saveAccessToken(accessToken);
    await saveRefreshToken(refreshToken);
    await saveUserRole(role);
  }

  /// Clear all stored auth data (logout).
  Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
    } catch (_) {}
  }

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
