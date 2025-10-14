import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import 'key_manager.dart';

class AuthService extends ChangeNotifier {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final Uuid _uuid = const Uuid();
  final KeyManager _keyManager = KeyManager();

  String? _userId;
  String? _username;
  bool _isLoggedIn = false;

  String get userId => _userId ?? '';
  String get username => _username ?? '';
  bool get isLoggedIn => _isLoggedIn;

  Future<void> _clearSession() async {
    await _storage.delete(key: 'current_session');
    await _storage.delete(key: 'user_id');
    _username = null;
    _userId = null;
    _isLoggedIn = false;
    notifyListeners();
  }

  Future<bool> checkLoginStatus() async {
    final isInitialized = await _keyManager.isInitialized();
    if (!isInitialized) {
      _isLoggedIn = false;
      notifyListeners();
      return false;
    }
    final session = await _storage.read(key: 'current_session');
    if (session == null) {
      _isLoggedIn = false;
      notifyListeners();
      return false;
    }
    _username = session;
    _userId = await _storage.read(key: 'user_id');
    _isLoggedIn = true;
    notifyListeners();
    return true;
  }

  Future<bool> authenticate(String username, String password) async {
    if (username.isEmpty || password.isEmpty) return false;
    final isInitialized = await _keyManager.isInitialized();
    if (!isInitialized) return false;
    final isValid = await _keyManager.verifyMasterPassword(password);
    if (!isValid) return false;
    final String newUserId = _uuid.v4();
    await _storage.write(key: 'current_session', value: username);
    await _storage.write(key: 'user_id', value: newUserId);
    _username = username;
    _userId = newUserId;
    _isLoggedIn = true;
    notifyListeners();
    return true;
  }

  Future<bool> register(String username, String masterPassword, String recoveryCode) async {
    if (username.isEmpty || masterPassword.isEmpty || recoveryCode.isEmpty) return false;
    final isInitialized = await _keyManager.isInitialized();
    if (isInitialized) return false;
    await _keyManager.initialize(masterPassword, recoveryCode);
    final String newUserId = _uuid.v4();
    await _storage.write(key: 'current_session', value: username);
    await _storage.write(key: 'user_id', value: newUserId);
    _username = username;
    _userId = newUserId;
    _isLoggedIn = true;
    notifyListeners();
    return true;
  }

  Future<void> logout() async {
    await _storage.delete(key: 'current_session');
    _username = null;
    _userId = null;
    _isLoggedIn = false;
    notifyListeners();
  }

  Future<bool> resetCredentials() async {
    await _keyManager.reset();
    await _clearSession();
    return true;
  }
}
