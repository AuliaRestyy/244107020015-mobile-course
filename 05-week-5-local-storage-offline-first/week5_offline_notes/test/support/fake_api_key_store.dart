import 'package:week5_offline_notes/features/chat/data/api_key_store.dart';

class FakeApiKeyStore implements ApiKeyStore {
  FakeApiKeyStore([this._key]);

  static const String fakeKey = 'test-key-123';

  String? _key;
  int readCount = 0;

  @override
  Future<String?> readKey() async {
    readCount++;
    return _key;
  }

  @override
  Future<void> saveKey(String key) async => _key = key;

  @override
  Future<void> clearKey() async => _key = null;
}
