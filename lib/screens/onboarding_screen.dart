
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class OnboardingScreen extends StatefulWidget {
  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _recoveryCtrl = TextEditingController();
  bool _creating = false;
  bool _showRecoveryInput = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    return Scaffold(
      appBar: AppBar(title: Text('Welcome to LockVerse')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: _creating ? 
          Center(child: CircularProgressIndicator()) : 
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Secure Your Files',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),
                TextField(
                  controller: _userCtrl,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _passCtrl,
                  decoration: InputDecoration(
                    labelText: 'Master Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                    helperText: 'This password will encrypt all your files',
                  ),
                  obscureText: true,
                ),
                if (_showRecoveryInput) ...[
                  SizedBox(height: 16),
                  TextField(
                    controller: _recoveryCtrl,
                    decoration: InputDecoration(
                      labelText: 'Recovery Code',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.key),
                      helperText: 'Save this code securely - you\'ll need it if you forget your password',
                    ),
                  ),
                ],
                SizedBox(height: 24),
                if (_error != null)
                  Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                      _error!,
                      style: TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    _showRecoveryInput ? 'Create Account' : 'Generate Recovery Code',
                    style: TextStyle(fontSize: 16),
                  ),
                  onPressed: () async {
                    if (!_showRecoveryInput) {
                      if (_userCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
                        setState(() => _error = 'Please fill in all fields');
                        return;
                      }
                      setState(() {
                        _showRecoveryInput = true;
                        _error = null;
                        _recoveryCtrl.text = _generateRecoveryCode();
                      });
                    } else {
                      await _createAccount(auth);
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _generateRecoveryCode() {
    // Generate a random 16-character recovery code
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final random = DateTime.now().millisecondsSinceEpoch;
    String code = '';
    var r = random;
    for (var i = 0; i < 16; i++) {
      code += chars[r % chars.length];
      r = r ~/ chars.length;
    }
    // Insert dashes every 4 characters
    return code.replaceAllMapped(
      RegExp(r'.{4}'),
      (match) => '${match.group(0)}-'
    ).substring(0, 19); // Remove trailing dash
  }

  Future<void> _createAccount(AuthService auth) async {
    if (_userCtrl.text.isEmpty || _passCtrl.text.isEmpty || _recoveryCtrl.text.isEmpty) {
      setState(() => _error = 'Please fill in all fields');
      return;
    }

    setState(() {
      _creating = true;
      _error = null;
    });

    try {
      final success = await auth.register(
        _userCtrl.text.trim(),
        _passCtrl.text,
        _recoveryCtrl.text,
      );

      if (success) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        setState(() => _error = 'Failed to create account');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _creating = false);
    }
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _recoveryCtrl.dispose();
    super.dispose();
  }
}
