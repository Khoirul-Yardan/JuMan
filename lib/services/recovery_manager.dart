
import 'dart:math';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'encryption_service.dart';

class RecoveryManager {
  final _storage = FlutterSecureStorage();

  static String generateRecoveryCode({int parts = 4, int partLen = 4}) {
    final rnd = Random.secure();
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    String part() => List.generate(partLen, (_) => alphabet[rnd.nextInt(alphabet.length)]).join();
    return List.generate(parts, (_) => part()).join('-');
  }

  Future<void> storeRecoveryCodeHash(String recoveryCode, String saltKey) async {
    final salt = base64.encode(EncryptionService.randomBytes(12));
    final hash = EncryptionService.hmacBase64(recoveryCode, salt);
    await _storage.write(key: saltKey, value: salt);
    await _storage.write(key: '${saltKey}_hash', value: hash);
  }

  Future<bool> verifyRecoveryCode(String candidate, String saltKey) async {
    final salt = await _storage.read(key: saltKey);
    final storedHash = await _storage.read(key: '${saltKey}_hash');
    if (salt == null || storedHash == null) return false;
    final check = EncryptionService.hmacBase64(candidate, salt);
    return check == storedHash;
  }

  Future<String> rotateRecoveryCode(String saltKey) async {
    final newCode = generateRecoveryCode();
    await storeRecoveryCodeHash(newCode, saltKey);
    return newCode;
  }
}
