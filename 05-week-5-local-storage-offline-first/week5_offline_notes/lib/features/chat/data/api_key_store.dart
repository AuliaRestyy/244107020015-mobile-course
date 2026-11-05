import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class ApiKeyStore {
  Future<String?> readKey();
  Future<void> saveKey(String key);
  Future<void> clearKey();
}

class SecureStorageApiKeyStore implements ApiKeyStore {
  SecureStorageApiKeyStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const String storageKey = 'gemini_api_key';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readKey() async {
    final value = await _storage.read(key: storageKey);
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  @override
  Future<void> saveKey(String key) =>
      _storage.write(key: storageKey, value: key.trim());

  @override
  Future<void> clearKey() => _storage.delete(key: storageKey);
}
