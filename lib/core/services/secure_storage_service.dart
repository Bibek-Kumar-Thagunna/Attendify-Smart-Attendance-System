import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SecureStorageService {
  final _storage = const FlutterSecureStorage();

  static const _keyRollNumber = 'auth_roll_number';
  static const _keyPassword = 'auth_password';

  Future<void> saveCredentials({
    required String rollNumber,
    required String password,
  }) async {
    await _storage.write(key: _keyRollNumber, value: rollNumber);
    await _storage.write(key: _keyPassword, value: password);
  }

  Future<Map<String, String>?> getCredentials() async {
    final rollNumber = await _storage.read(key: _keyRollNumber);
    final password = await _storage.read(key: _keyPassword);

    if (rollNumber != null && password != null) {
      return {'rollNumber': rollNumber, 'password': password};
    }
    return null;
  }

  Future<void> clearCredentials() async {
    await _storage.delete(key: _keyRollNumber);
    await _storage.delete(key: _keyPassword);
  }
}

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});
