
import 'dart:math';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'encryption_service.dart';

class RecoveryManager {
  final _storage = FlutterSecureStorage();
  
  static const _masterKeyBackupKey = 'master_key_backup';
  static const _masterKeyBackupNonceKey = 'master_key_backup_nonce';

  /// Generate a human-readable recovery code in parts
  static String generateRecoveryCode({int parts = 4, int partLen = 4}) {
    final rnd = Random.secure();
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    String part() => List.generate(partLen, (_) => alphabet[rnd.nextInt(alphabet.length)]).join();
    return List.generate(parts, (_) => part()).join('-');
  }

  /// Store a salted hash of the recovery code
  Future<void> storeRecoveryCodeHash(String recoveryCode, String saltKey) async {
    final salt = base64.encode(EncryptionService.randomBytes(12));
    final hash = EncryptionService.hmacBase64(recoveryCode, salt);
    await _storage.write(key: saltKey, value: salt);
    await _storage.write(key: '${saltKey}_hash', value: hash);
  }

  /// Verify a candidate recovery code against stored hash
  Future<bool> verifyRecoveryCode(String candidate, String saltKey) async {
    final salt = await _storage.read(key: saltKey);
    final storedHash = await _storage.read(key: '${saltKey}_hash');
    if (salt == null || storedHash == null) return false;
    final check = EncryptionService.hmacBase64(candidate, salt);
    return check == storedHash;
  }

  /// Generate a new recovery code and store its hash
  Future<String> rotateRecoveryCode(String saltKey) async {
    final newCode = generateRecoveryCode();
    await storeRecoveryCodeHash(newCode, saltKey);
    return newCode;
  }

  /// Backup master key encrypted with recovery code
  Future<void> backupMasterKey(List<int> masterKey, String recoveryCode) async {
    // Generate a salt and derive encryption key from recovery code
    final salt = EncryptionService.randomBytes(16);
    final derivedKey = EncryptionService.pbkdf2(recoveryCode, salt, 100000, 32);
    
    // Convert master key to Uint8List
    final masterKeyBytes = Uint8List.fromList(masterKey);
    
    // Encrypt master key with derived key
    final encrypted = EncryptionService.encryptBytes(masterKeyBytes, derivedKey);

    // Store encrypted master key and salt
    await _storage.write(key: _masterKeyBackupKey, value: encrypted['cipher']);
    await _storage.write(key: '${_masterKeyBackupKey}_iv', value: encrypted['iv']);
    await _storage.write(key: '${_masterKeyBackupKey}_salt', value: base64.encode(salt));
  }

  /// Recover master key using recovery code
  Future<List<int>> recoverMasterKey(String recoveryCode) async {
    final encryptedKey = await _storage.read(key: _masterKeyBackupKey);
    final iv = await _storage.read(key: '${_masterKeyBackupKey}_iv');
    final saltBase64 = await _storage.read(key: '${_masterKeyBackupKey}_salt');
    
    if (encryptedKey == null || iv == null || saltBase64 == null) {
      throw Exception('No master key backup found');
    }

    final salt = base64.decode(saltBase64);
    final derivedKey = EncryptionService.pbkdf2(recoveryCode, salt, 100000, 32);
    
    try {
      final masterKey = EncryptionService.decryptBytes(
        encryptedKey,
        iv,
        derivedKey,
      );
      return masterKey.toList();
    } catch (e) {
      throw Exception('Failed to recover master key: Invalid recovery code');
    }
  }

  /// Clear stored recovery data
  Future<void> clearRecoveryData() async {
    await _storage.delete(key: _masterKeyBackupKey);
    await _storage.delete(key: _masterKeyBackupNonceKey);
  }
}
