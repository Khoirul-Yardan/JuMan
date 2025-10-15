
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'encryption_service.dart';

class KeyManager {
  final _storage = FlutterSecureStorage();
  // rootKey is random 32 bytes used to wrap per-file keys. Encrypted by master-derived key and by recovery-code-derived key backup.

  static const _masterKeyKey = 'master_key';
  static const _rootWrappedKeyKey = 'root_wrapped_by_master';
  static const _rootBackupWrappedKey = 'root_wrapped_by_recovery';
  static const _isInitializedKey = 'is_initialized';

  // Check if key manager is initialized
  Future<bool> isInitialized() async {
    final initialized = await _storage.read(key: _isInitializedKey);
    return initialized == 'true';
  }

  // Initialize key manager with master password and recovery code
  Future<void> initialize(String masterPassword, String recoveryCode) async {
    final isAlreadyInitialized = await isInitialized();
    if (isAlreadyInitialized) {
      throw Exception('KeyManager is already initialized');
    }

    // Generate master key from password
    final salt = EncryptionService.randomBytes(12);
    final masterKey = EncryptionService.pbkdf2(masterPassword, salt, 10000, 32);
    
    // Store master key
    await _storage.write(key: _masterKeyKey, value: base64.encode(masterKey));
    await _storage.write(key: 'master_salt', value: base64.encode(salt));

    // Create and store root key
    await createAndStoreRoot(masterKey, recoveryCode);
    
    // Mark as initialized
    await _storage.write(key: _isInitializedKey, value: 'true');
  }

  // Reset key manager (for recovery or complete reset)
  Future<void> reset() async {
    await _storage.deleteAll();
  }
  
  Future<Uint8List?> getMasterKey() async {
    final masterKeyB64 = await _storage.read(key: _masterKeyKey);
    if (masterKeyB64 == null) return null;
    return base64.decode(masterKeyB64);
  }

  Future<Uint8List?> deriveMasterKey(String masterPassword) async {
    final saltB64 = await _storage.read(key: 'master_salt');
    if (saltB64 == null) return null;
    final salt = base64.decode(saltB64);
    return EncryptionService.pbkdf2(masterPassword, salt, 10000, 32);
  }

  // Verify if the master password is correct
  Future<bool> verifyMasterPassword(String masterPassword) async {
    final storedKeyB64 = await _storage.read(key: _masterKeyKey);
    if (storedKeyB64 == null) return false;
    
    final derivedKey = await deriveMasterKey(masterPassword);
    if (derivedKey == null) return false;
    
    final storedKey = base64.decode(storedKeyB64);
    
    // Compare the keys
    if (derivedKey.length != storedKey.length) return false;
    for (var i = 0; i < derivedKey.length; i++) {
      if (derivedKey[i] != storedKey[i]) return false;
    }
    return true;
  }

  // create root key and wrap with masterKeyBytes, and also wrap backup with recoveryKeyBytes
  Future<void> createAndStoreRoot(Uint8List masterKeyBytes, String recoveryCode) async {
    final root = EncryptionService.randomBytes(32);
    // wrap root with masterKey (encrypt root bytes)
    final wrapped = EncryptionService.encryptBytes(root, masterKeyBytes);
    await _storage.write(key: _rootWrappedKeyKey, value: json.encode(wrapped));
    
    // create recovery-wrapped root
    final recoverySalt = EncryptionService.randomBytes(12);
    final recoveryKey = EncryptionService.pbkdf2(recoveryCode, recoverySalt, 10000, 32);
    final wrappedRecovery = EncryptionService.encryptBytes(root, recoveryKey);
    
    await Future.wait([
      _storage.write(key: _rootBackupWrappedKey, value: json.encode(wrappedRecovery)),
      _storage.write(key: 'recovery_salt', value: base64.encode(recoverySalt))
    ]);
  }

  // unwrap root with masterKeyBytes
  Future<Uint8List?> unwrapRootWithMaster(Uint8List masterKeyBytes) async {
    final jsonStr = await _storage.read(key: _rootWrappedKeyKey);
    if (jsonStr == null) return null;
    final Map<String, dynamic> m = json.decode(jsonStr) as Map<String, dynamic>;
    final cipher = m['cipher'] as String;
    final iv = m['iv'] as String;
    return EncryptionService.decryptBytes(cipher, iv, masterKeyBytes);
  }

  // recover root with recoveryCode (one-time use expected by caller)
  Future<Uint8List?> recoverRootWithRecoveryCode(String recoveryCode) async {
    final jsonStr = await _storage.read(key: _rootBackupWrappedKey);
    final salt = await _storage.read(key: 'recovery_salt');
    
    if (jsonStr == null || salt == null) return null;
    final Map<String, dynamic> m = json.decode(jsonStr) as Map<String, dynamic>;
    final recoveryKey = EncryptionService.pbkdf2(
      recoveryCode, 
      base64.decode(salt),
      10000,
      32,
    );

    try {
      final cipher = m['cipher'] as String;
      final iv = m['iv'] as String;
      return EncryptionService.decryptBytes(cipher, iv, recoveryKey);
    } catch (e) {
      print('Recovery failed: $e');
      return null;
    }
  }

  // helper to rotate backup (one-time usage pattern)
  Future<void> rotateRecoveryBackup(String newRecoveryCode, Uint8List masterKeyBytes) async {
    final root = await unwrapRootWithMaster(masterKeyBytes);
    if (root == null) throw Exception('root unavailable');
    final recoveryKey = EncryptionService.pbkdf2(newRecoveryCode, EncryptionService.randomBytes(12), 10000, 32);
    final wrappedRecovery = EncryptionService.encryptBytes(root, recoveryKey);
    await _storage.write(key: _rootBackupWrappedKey, value: json.encode(wrappedRecovery));
  }

  Future<void> rewrapRootKey(Uint8List rootKey, Uint8List newMasterKey) async {
    final wrapped = EncryptionService.encryptBytes(rootKey, newMasterKey);
    await _storage.write(key: _rootWrappedKeyKey, value: json.encode(wrapped));
  }
}
