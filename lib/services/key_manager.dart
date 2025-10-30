import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart'; // TAMBAHKAN INI
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'encryption_service.dart';

class KeyManager {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const int _requiredKeyLength = 32; // 256 bits for AES-256

  Future<bool> isInitialized() async {
    final masterKey = await _storage.read(key: 'master_key');
    final rootKey = await _storage.read(key: 'root_key');
    return masterKey != null && rootKey != null;
  }

  Future<void> initialize(String masterPassword, String recoveryCode) async {
    try {
      // Generate master key from password
      final salt = EncryptionService.randomBytes(12);
      final masterKey = EncryptionService.pbkdf2(masterPassword, salt, 10000, 32);
      
      // Generate root key - FIX: Ensure it's 32 bytes
      final rootKey = _generateSecureRootKey();
      
      // Wrap root key with master key
      final wrappedRoot = EncryptionService.encryptBytes(rootKey, masterKey);
      
      // Create recovery key and wrap root key with it
      final recoveryKey = _deriveRecoveryKey(recoveryCode);
      final wrappedWithRecovery = EncryptionService.encryptBytes(rootKey, recoveryKey);
      
      // Store everything
      await _storage.write(key: 'master_salt', value: base64.encode(salt));
      await _storage.write(key: 'master_key', value: base64.encode(masterKey));
      await _storage.write(key: 'root_key', value: wrappedRoot['cipher']);
      await _storage.write(key: 'root_iv', value: wrappedRoot['iv']);
      await _storage.write(key: 'recovery_wrapped', value: wrappedWithRecovery['cipher']);
      await _storage.write(key: 'recovery_iv', value: wrappedWithRecovery['iv']);
      
    } catch (e) {
      await reset();
      rethrow;
    }
  }

  Uint8List _generateSecureRootKey() {
    // FIX: Always generate exactly 32 bytes
    final randomKey = EncryptionService.randomBytes(32);
    
    // Double validation
    if (randomKey.length != _requiredKeyLength) {
      // Fallback: Use hash to ensure 32 bytes
      final hash = sha256.convert(randomKey);
      return Uint8List.fromList(hash.bytes);
    }
    
    return randomKey;
  }

  Uint8List _deriveRecoveryKey(String recoveryCode) {
    final salt = utf8.encode('recovery_salt');
    final key = EncryptionService.pbkdf2(recoveryCode, Uint8List.fromList(salt), 10000, 32);
    return key;
  }

  Future<Uint8List?> getMasterKey() async {
    try {
      final masterKeyBase64 = await _storage.read(key: 'master_key');
      if (masterKeyBase64 == null) return null;
      return base64.decode(masterKeyBase64);
    } catch (e) {
      return null;
    }
  }

  Future<Uint8List?> unwrapRootWithMaster(Uint8List masterKey) async {
    try {
      final wrappedCipher = await _storage.read(key: 'root_key');
      final wrappedIv = await _storage.read(key: 'root_iv');
      
      if (wrappedCipher == null || wrappedIv == null) {
        return null;
      }

      print('Unwrapping root key with master key length: ${masterKey.length}');
      
      // Unwrap the root key
      final unwrapped = EncryptionService.decryptBytes(wrappedCipher, wrappedIv, masterKey);
      
      print('Root key unwrapped successfully, length: ${unwrapped.length}');
      
      // FIX: Ensure the unwrapped key is exactly 32 bytes
      return _ensureKeyLength(unwrapped);
    } catch (e) {
      print('Error unwrapping root key: $e');
      return null;
    }
  }

  Uint8List _ensureKeyLength(Uint8List key) {
    if (key.length == _requiredKeyLength) {
      return key;
    }
    
    print('Fixing key length from ${key.length} to $_requiredKeyLength bytes');
    
    if (key.length > _requiredKeyLength) {
      // Take first 32 bytes
      return key.sublist(0, _requiredKeyLength);
    } else {
      // Extend using hash for consistent 32 bytes
      final hash = sha256.convert(key);
      return Uint8List.fromList(hash.bytes);
    }
  }

  Future<Uint8List?> recoverRootWithRecoveryCode(String recoveryCode) async {
    try {
      final wrappedCipher = await _storage.read(key: 'recovery_wrapped');
      final wrappedIv = await _storage.read(key: 'recovery_iv');
      
      if (wrappedCipher == null || wrappedIv == null) {
        return null;
      }

      final recoveryKey = _deriveRecoveryKey(recoveryCode);
      final unwrapped = EncryptionService.decryptBytes(wrappedCipher, wrappedIv, recoveryKey);
      
      return _ensureKeyLength(unwrapped);
    } catch (e) {
      print('Recovery failed: $e');
      return null;
    }
  }

  Future<bool> verifyMasterPassword(String password) async {
    try {
      final saltBase64 = await _storage.read(key: 'master_salt');
      if (saltBase64 == null) return false;
      
      final salt = base64.decode(saltBase64);
      final testMasterKey = EncryptionService.pbkdf2(password, salt, 10000, 32);
      final storedMasterKey = await getMasterKey();
      
      // FIX: Gunakan listEquals dari package foundation
      return storedMasterKey != null && 
             listEquals(testMasterKey, storedMasterKey);
    } catch (e) {
      return false;
    }
  }

  Future<void> rewrapRootKey(Uint8List rootKey, Uint8List newMasterKey) async {
    final wrapped = EncryptionService.encryptBytes(rootKey, newMasterKey);
    await _storage.write(key: 'root_key', value: wrapped['cipher']);
    await _storage.write(key: 'root_iv', value: wrapped['iv']);
  }

  Future<void> rotateRecoveryBackup(String recoveryCode, Uint8List masterKey) async {
    final rootKey = await unwrapRootWithMaster(masterKey);
    if (rootKey == null) throw Exception('Root key not available');
    
    final recoveryKey = _deriveRecoveryKey(recoveryCode);
    final wrappedWithRecovery = EncryptionService.encryptBytes(rootKey, recoveryKey);
    
    await _storage.write(key: 'recovery_wrapped', value: wrappedWithRecovery['cipher']);
    await _storage.write(key: 'recovery_iv', value: wrappedWithRecovery['iv']);
  }

  Future<void> reset() async {
    await _storage.deleteAll();
  }
}