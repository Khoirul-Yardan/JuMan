import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import 'key_manager.dart'; // GUNAKAN KeyManager yang sudah diperbaiki
import 'encryption_service.dart';

class AuthService extends ChangeNotifier {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final Uuid _uuid = const Uuid();
  final KeyManager _keyManager = KeyManager(); // GUNAKAN KeyManager yang sudah diperbaiki

  String? _userId;
  String? _username;
  bool _isLoggedIn = false;
  bool _isInitializing = false;

  String get userId => _userId ?? '';
  String get username => _username ?? '';
  bool get isLoggedIn => _isLoggedIn;
  bool get isInitializing => _isInitializing;

  Future<void> _clearSession() async {
    await _storage.delete(key: 'current_session');
    await _storage.delete(key: 'user_id');
    await _storage.delete(key: 'session_token');
    _username = null;
    _userId = null;
    _isLoggedIn = false;
    notifyListeners();
  }

  Future<bool> checkLoginStatus() async {
    if (_isInitializing) return false;
    
    _isInitializing = true;
    notifyListeners();

    try {
      await Future.delayed(Duration(milliseconds: 500)); // Simulate loading

      final isInitialized = await _keyManager.isInitialized();
      if (!isInitialized) {
        _isLoggedIn = false;
        _isInitializing = false;
        notifyListeners();
        return false;
      }

      final sessionToken = await _storage.read(key: 'session_token');
      final sessionUser = await _storage.read(key: 'current_session');
      
      if (sessionToken == null || sessionUser == null) {
        _isLoggedIn = false;
        _isInitializing = false;
        notifyListeners();
        return false;
      }

      // Validate session token
      final tokenData = json.decode(sessionToken);
      final expiry = DateTime.parse(tokenData['expiry']);
      
      if (expiry.isBefore(DateTime.now())) {
        await _clearSession();
        _isInitializing = false;
        notifyListeners();
        return false;
      }

      _username = sessionUser;
      _userId = await _storage.read(key: 'user_id');
      _isLoggedIn = true;
      
      _isInitializing = false;
      notifyListeners();
      return true;
    } catch (e) {
      await _clearSession();
      _isInitializing = false;
      notifyListeners();
      return false;
    }
  }

  /// Create session token with expiry
  Future<void> _createSession(String username) async {
    final sessionData = {
      'created': DateTime.now().toIso8601String(),
      'expiry': DateTime.now().add(Duration(days: 30)).toIso8601String(),
      'token': _uuid.v4(),
    };
    
    await _storage.write(key: 'session_token', value: json.encode(sessionData));
    await _storage.write(key: 'current_session', value: username);
  }

  /// Initialize default admin account if not exists
  Future<void> initializeDefaultAccount() async {
    final isInitialized = await _keyManager.isInitialized();
    if (!isInitialized) {
      const defaultUsername = 'admin';
      const defaultPassword = '123';
      
      // Get or create recovery code
      String? existingRecoveryCode = await _storage.read(key: 'recovery_code');
      String recoveryCode = existingRecoveryCode ?? EncryptionService.generateSecurePassword(length: 16);
      
      try {
        await _keyManager.initialize(defaultPassword, recoveryCode);
        
        final String newUserId = _uuid.v4();
        await _createSession(defaultUsername);
        await _storage.write(key: 'user_id', value: newUserId);
        await _storage.write(key: 'username', value: defaultUsername);
        
        // Only save recovery code if it doesn't exist
        if (existingRecoveryCode == null) {
          await _storage.write(key: 'recovery_code', value: recoveryCode);
          print('Default account created with recovery code: $recoveryCode');
        }
        
      } catch (e) {
        await _keyManager.reset();
        throw Exception('Failed to initialize default account: $e');
      }
    }
  }

  /// Get stored recovery code
  Future<String?> getRecoveryCode() async {
    return _storage.read(key: 'recovery_code');
  }

  Future<bool> authenticate(String username, String password) async {
    if (_isInitializing) return false;
    
    _isInitializing = true;
    notifyListeners();

    try {
      if (username.isEmpty || password.isEmpty) {
        _isInitializing = false;
        notifyListeners();
        return false;
      }
      
      // Ensure default account exists
      await initializeDefaultAccount();
      
      final isInitialized = await _keyManager.isInitialized();
      if (!isInitialized) {
        _isInitializing = false;
        notifyListeners();
        return false;
      }

      // Verify credentials
      final storedUsername = await _storage.read(key: 'username');
      if (username != storedUsername) {
        _isInitializing = false;
        notifyListeners();
        return false;
      }

      final isValid = await _keyManager.verifyMasterPassword(password);
      if (!isValid) {
        _isInitializing = false;
        notifyListeners();
        return false;
      }

      // Create new session
      final String newUserId = _uuid.v4();
      await _createSession(username);
      await _storage.write(key: 'user_id', value: newUserId);
      
      _username = username;
      _userId = newUserId;
      _isLoggedIn = true;
      _isInitializing = false;
      
      notifyListeners();
      return true;
    } catch (e) {
      _isInitializing = false;
      notifyListeners();
      return false;
    }
  }

  /// Change username and password
  Future<bool> changeCredentials(String currentPassword, String newUsername, String newPassword) async {
    if (currentPassword.isEmpty || newUsername.isEmpty || newPassword.isEmpty) return false;
    
    try {
      // Verify current password
      if (!await _keyManager.verifyMasterPassword(currentPassword)) {
        throw Exception('Current password is incorrect');
      }
      
      // Get master key
      final masterKey = await _keyManager.getMasterKey();
      if (masterKey == null) throw Exception('Master key not available');
      
      // Generate new master key from new password
      final salt = EncryptionService.randomBytes(12);
      final newMasterKey = EncryptionService.pbkdf2(newPassword, salt, 10000, 32);
      
      // Store new credentials
      await _storage.write(key: 'username', value: newUsername);
      await _storage.write(key: 'master_salt', value: base64.encode(salt));
      await _storage.write(key: 'master_key', value: base64.encode(newMasterKey));
      
      // Re-wrap root key with new master key
      final rootKey = await _keyManager.unwrapRootWithMaster(masterKey);
      if (rootKey == null) throw Exception('Root key not available');
      await _keyManager.rewrapRootKey(rootKey, newMasterKey);
      
      // Update session
      await _createSession(newUsername);
      _username = newUsername;
      notifyListeners();
      
      return true;
    } catch (e) {
      print('Failed to change credentials: $e');
      return false;
    }
  }

  Future<void> logout() async {
    _isInitializing = true;
    notifyListeners();
    
    await Future.delayed(Duration(milliseconds: 500));
    await _clearSession();
    
    _isInitializing = false;
    notifyListeners();
  }

  Future<bool> resetCredentials() async {
    await _keyManager.reset();
    await _clearSession();
    return true;
  }

  /// Recover account using recovery code and create new master password - PERBAIKAN
  Future<bool> recoverAccount(String recoveryCode, String newMasterPassword) async {
    if (recoveryCode.isEmpty || newMasterPassword.isEmpty) return false;
    
    _isInitializing = true;
    notifyListeners();

    try {
      final isInitialized = await _keyManager.isInitialized();
      if (!isInitialized) {
        print('KeyManager not initialized');
        _isInitializing = false;
        notifyListeners();
        return false;
      }

      // Attempt to recover root key using recovery code
      print('Attempting to recover root key...');
      final rootKey = await _keyManager.recoverRootWithRecoveryCode(recoveryCode.trim());
      if (rootKey == null) {
        print('Failed to recover root key - invalid recovery code or corrupted data');
        _isInitializing = false;
        notifyListeners();
        return false;
      }

      print('Root key recovered successfully, length: ${rootKey.length}');

      // Generate new master key from new password
      final salt = EncryptionService.randomBytes(12);
      final newMasterKey = EncryptionService.pbkdf2(newMasterPassword, salt, 10000, 32);
      
      // Store new master key
      await _storage.write(key: 'master_salt', value: base64.encode(salt));
      await _storage.write(key: 'master_key', value: base64.encode(newMasterKey));
      
      // Re-wrap root key with new master key
      await _keyManager.rewrapRootKey(rootKey, newMasterKey);
      
      // Update recovery backup dengan recovery code yang SAMA
      await _keyManager.rotateRecoveryBackup(recoveryCode.trim(), newMasterKey);
      
      // Create new session
      final username = await _storage.read(key: 'username') ?? 'admin';
      await _createSession(username);
      _username = username;
      _isLoggedIn = true;

      print('Account recovery completed successfully');
      _isInitializing = false;
      notifyListeners();
      return true;
    } catch (e) {
      print('Account recovery failed: $e');
      _isInitializing = false;
      notifyListeners();
      return false;
    }
  }
  
  /// Update recovery code (requires current master password)
  Future<String?> updateRecoveryCode(String masterPassword) async {
    if (masterPassword.isEmpty) return null;
    
    try {
      // Verify master password
      if (!await _keyManager.verifyMasterPassword(masterPassword)) {
        throw Exception('Invalid master password');
      }
      
      // Get master key
      final masterKey = await _keyManager.getMasterKey();
      if (masterKey == null) throw Exception('Master key not available');
      
      // Generate new recovery code
      final newRecoveryCode = EncryptionService.generateSecurePassword(length: 16);
      
      // Update recovery backup
      await _keyManager.rotateRecoveryBackup(newRecoveryCode, masterKey);
      
      // Update stored recovery code
      await _storage.write(key: 'recovery_code', value: newRecoveryCode);
      
      return newRecoveryCode;
    } catch (e) {
      print('Failed to update recovery code: $e');
      return null;
    }
  }
}