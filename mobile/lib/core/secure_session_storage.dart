import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Stores the Supabase session token in the OS secure store:
///   • Android — EncryptedSharedPreferences (AES-256)
///   • iOS/macOS — Keychain (first_unlock accessibility)
///
/// Pass an instance to [Supabase.initialize] via the [localStorage] parameter.
class SecureSessionStorage extends LocalStorage {
  static const _sessionKey = 'supabase_session';

  // One shared instance — avoids recreating the storage object on every call.
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  /// Called once by Supabase on startup. Nothing to initialise here.
  @override
  Future<void> initialize() async {}

  /// Returns true if a persisted session exists in secure storage.
  @override
  Future<bool> hasAccessToken() {
    return _storage.containsKey(key: _sessionKey);
  }

  /// Returns the raw session string, or null if none is stored.
  @override
  Future<String?> accessToken() {
    return _storage.read(key: _sessionKey);
  }

  /// Writes [persistSessionString] to secure storage.
  @override
  Future<void> persistSession(String persistSessionString) {
    return _storage.write(key: _sessionKey, value: persistSessionString);
  }

  /// Deletes the stored session (called on sign-out).
  @override
  Future<void> removePersistedSession() {
    return _storage.delete(key: _sessionKey);
  }
}